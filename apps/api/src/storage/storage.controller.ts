import { Body, Controller, Get, Post, Query, UseGuards, UseInterceptors, UploadedFile, BadRequestException, Res, Inject } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { StorageService } from './storage.service';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import type { Response } from 'express';
import { SkipThrottle } from '@nestjs/throttler';
import { buildBatchMediaUrls } from '../common/listing-media-url.util';

// Minimal shape for uploaded file to avoid Express.Multer type dependency
type Uploaded = {
  originalname?: string;
  mimetype?: string;
  buffer: Buffer;
};

@Controller('v1/storage')
export class StorageController {
  constructor(
    private storage: StorageService,
    @Inject(CACHE_MANAGER) private cache: Cache,
  ) {}

  @Post('upload-url')
  @UseGuards(JwtAuthGuard)
  async uploadUrl(
    @CurrentUser() user: any,
    @Body() dto: { domain: 'profiles' | 'communities' | 'gifts' | 'donations' | 'trades' | 'ads' | 'chat'; contentType: string; ext: string },
  ) {
    return this.storage.createUploadUrl(dto.domain, user.sub, dto.contentType, dto.ext);
  }

  // Server-side upload (multipart/form-data; field name: file). Returns { key }.
  @Post('upload')
  @UseGuards(JwtAuthGuard)
  @UseInterceptors(FileInterceptor('file', { storage: memoryStorage() }))
  async upload(
    @CurrentUser() user: any,
    @UploadedFile() file: Uploaded,
    @Body() body: { domain?: 'profiles' | 'communities' | 'gifts' | 'donations' | 'trades' | 'ads' | 'chat'; ext?: string },
  ) {
    if (!file) throw new BadRequestException('file is required');
    const domain = body?.domain ?? 'profiles';
    // infer ext if not provided
    const orig = file.originalname?.toLowerCase() || '';
    const inferredExt = body?.ext
      || (orig.endsWith('.png') ? 'png'
        : (orig.endsWith('.jpeg') ? 'jpeg'
          : (orig.endsWith('.jpg') ? 'jpg'
            : (orig.endsWith('.heic') ? 'heic' : 'bin'))));
    const contentType = file.mimetype || 'application/octet-stream';
    return this.storage.uploadObject(domain, user.sub, file.buffer, contentType, inferredExt);
  }

  @Get('download-url')
  @SkipThrottle()
  @UseGuards(JwtAuthGuard)
  async downloadUrl(@Query('key') key: string) {
    try {
      if (!key || key.startsWith('/') || key.startsWith('file:')) {
        return { url: null };
      }

      const cacheKey = `storage:download-url:${key}`;
      const cached = await this.cache.get<{ url: string | null }>(cacheKey);
      if (cached) {
        return cached;
      }

      const presign = ((process.env.STORAGE_PRESIGN_DOWNLOAD ?? 'true').toLowerCase() === 'true');
      let result: { url: string | null };
      if (!presign) {
        const protocol = 'http';
        const host = process.env.HOST ?? 'localhost';
        const port = Number(process.env.PORT ?? 3000);
        const base =
          (process.env.API_PUBLIC_BASE_URL || process.env.APP_PUBLIC_URL || '').trim().replace(/\/$/, '') ||
          `${protocol}://${host}:${port}`;
        const url = `${base}/v1/storage/object?key=${encodeURIComponent(key)}`;
        result = { url };
      } else {
        result = await this.storage.createDownloadUrl(key);
      }

      const ttlSeconds = Number(process.env.STORAGE_DOWNLOAD_URL_CACHE_TTL ?? 3300);
      await this.cache.set(cacheKey, result, ttlSeconds);
      return result;
    } catch (err) {
      return { url: null };
    }
  }

  /** Batch-resolve stable listing media URLs for feed prefetch (max 50 keys). */
  @Post('resolve-batch')
  @SkipThrottle()
  async resolveBatch(@Body() body: { keys?: string[] }) {
    const keys = Array.isArray(body?.keys) ? body.keys : [];
    const unique = [...new Set(keys.map((k) => String(k).trim()).filter(Boolean))].slice(
      0,
      50,
    );
    const urls = await buildBatchMediaUrls(unique);
    return { urls };
  }

  @Get('object')
  @SkipThrottle()
  async streamObject(
    @Query('key') key: string,
    @Query('download') download?: string,
    @Query('filename') filename?: string,
    @Query('nocache') nocache?: string,
    @Query('maxage') maxage?: string,
    @Query('disposition') disposition?: string,
    @Query('inline') inline?: string,
    @Query('dl') dl?: string,
    @Query('ctype') ctype?: string,
    @Query('mime') mime?: string,
    @Res() res?: Response,
  ) {
    if (!key || key.startsWith('/') || key.startsWith('file:')) {
      throw new BadRequestException('Invalid storage key');
    }

    try {
      // Prefer redirecting to a presigned / direct bucket URL so mobile clients
      // fetch media without the API proxying S3 streams (which can hang on Railway).
      const redirectUrl = await this.storage.getPublicObjectRedirectUrl(key);
      if (redirectUrl) {
        if (nocache === '1') {
          res?.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
        } else if (maxage) {
          res?.setHeader('Cache-Control', `public, max-age=${parseInt(maxage, 10) || 0}`);
        } else {
          res?.setHeader('Cache-Control', 'public, max-age=86400, immutable');
        }
        res?.redirect(302, redirectUrl);
        return;
      }

      const { body, contentType, contentLength, lastModified, etag } = await this.storage.getObject(key);
      const ct = ctype || mime || contentType || 'application/octet-stream';
      if (ct) res?.setHeader('Content-Type', ct);
      if (contentLength) res?.setHeader('Content-Length', String(contentLength));
      if (lastModified) res?.setHeader('Last-Modified', new Date(lastModified).toUTCString());
      if (etag) res?.setHeader('ETag', etag);
      const disp = disposition || (download === '1' || dl === '1' || inline === '0' ? 'attachment' : 'inline');
      const fname = filename || undefined;
      if (disp) res?.setHeader('Content-Disposition', `${disp}${fname ? `; filename=\"${fname}\"` : ''}`);
      if (nocache === '1') {
        res?.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0');
        res?.setHeader('Pragma', 'no-cache');
        res?.setHeader('Expires', '0');
      } else if (maxage) {
        res?.setHeader('Cache-Control', `public, max-age=${parseInt(maxage, 10) || 0}`);
      } else {
        res?.setHeader('Cache-Control', 'public, max-age=86400, immutable');
      }
      (body as unknown as NodeJS.ReadableStream).pipe(res!);
    } catch (err: any) {
      throw new BadRequestException(err?.message || 'Failed to stream object');
    }
  }
}
