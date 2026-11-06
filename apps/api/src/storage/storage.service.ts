import { Injectable } from '@nestjs/common';
import { S3Client, PutObjectCommand, GetObjectCommand, HeadObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';
import * as http from 'http';
import * as https from 'https';
import { URL } from 'url';

@Injectable()
export class StorageService {
  private readonly region = process.env.STORAGE_REGION || 'us-east-1';
  private readonly credentials =
    process.env.STORAGE_ACCESS_KEY_ID && process.env.STORAGE_SECRET_ACCESS_KEY
      ? {
          accessKeyId: process.env.STORAGE_ACCESS_KEY_ID,
          secretAccessKey: process.env.STORAGE_SECRET_ACCESS_KEY,
        }
      : undefined;

  /** Used for Put/Get from the API process (usually localhost MinIO from the host). */
  private s3 = new S3Client({
    region: this.region,
    endpoint: process.env.STORAGE_ENDPOINT,
    credentials: this.credentials,
    forcePathStyle: true,
  });

  /**
   * Optional host embedded in presigned GET URLs. When the API runs on your Mac and the app
   * runs on the Android emulator, STORAGE_ENDPOINT is often http://localhost:9000 — presigned
   * URLs then point at the emulator's own loopback and images fail. Set STORAGE_PRESIGN_ENDPOINT
   * to http://10.0.2.2:9000 so signatures match the host the emulator uses to reach MinIO.
   */
  private s3Presign = new S3Client({
    region: this.region,
    endpoint: (process.env.STORAGE_PRESIGN_ENDPOINT || process.env.STORAGE_ENDPOINT || '').trim() || undefined,
    credentials: this.credentials,
    forcePathStyle: true,
  });

  private bucket = process.env.STORAGE_BUCKET || '';
  private endpoint = process.env.STORAGE_ENDPOINT || '';
  private ttl = Number(process.env.STORAGE_SIGNED_URL_TTL_SECONDS || 300);
  // Allow disabling presigned download URLs in local dev to avoid signature/compat issues
  // When disabled, we return a direct object URL (requires bucket policy to allow anonymous GET).
  private presignDownload = ((process.env.STORAGE_PRESIGN_DOWNLOAD ?? 'true').toLowerCase() === 'true');

  private key(domain: string, userId: string, ext: string) {
    return `${domain}/${userId}/${randomUUID()}.${ext}`;
  }

  async createUploadUrl(domain: string, userId: string, contentType: string, ext: string) {
    const k = this.key(domain, userId, ext);
    const cmd = new PutObjectCommand({ Bucket: this.bucket, Key: k, ContentType: contentType });
    const uploadUrl = await getSignedUrl(this.s3, cmd, { expiresIn: this.ttl });
    return { key: k, uploadUrl };
  }

  async createDownloadUrl(key: string) {
    if (!key || typeof key !== 'string') {
      return { url: null };
    }
    // Guard against local device paths accidentally stored in mediaKeys.
    if (key.startsWith('/') || key.startsWith('file:')) {
      return { url: null };
    }
    if (!this.bucket) {
      return { url: null };
    }
    // In local dev (or when explicitly configured), return a direct object URL instead of presigned.
    // This strips any checksum/signature query params and relies on bucket policy for access.
    if (!this.presignDownload && this.endpoint) {
      const direct = `${this.endpoint.replace(/\/$/, '')}/${this.bucket}/${key}`;
      return { url: direct };
    }
    try {
      const cmd = new GetObjectCommand({ Bucket: this.bucket, Key: key });
      const signer = process.env.STORAGE_PRESIGN_ENDPOINT?.trim() ? this.s3Presign : this.s3;
      const url = await getSignedUrl(signer, cmd, { expiresIn: this.ttl });
      return { url };
    } catch (err: any) {
      // Return null to let clients fall back to placeholders instead of surfacing 500s.
      return { url: null };
    }
  }

  /**
   * Returns a client-fetchable URL for [key] without reading the object through
   * the API process. Used by GET /v1/storage/object to 302-redirect instead of
   * proxy-streaming (Railway->S3 pipes can hang indefinitely on some hosts).
   */
  async getPublicObjectRedirectUrl(key: string): Promise<string | null> {
    const result = await this.createDownloadUrl(key);
    return result.url;
  }

  // Server-side upload (no CORS required). Returns the generated object key.
  async uploadObject(domain: string, userId: string, body: Buffer, contentType: string, ext: string) {
    const k = this.key(domain, userId, ext);
    await this.putObjectKey(k, body, contentType);
    return { key: k };
  }

  async putObjectKey(key: string, body: Buffer, contentType: string) {
    if (!this.bucket) throw new Error('STORAGE_BUCKET is not configured');
    await this.s3.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: body,
        ContentType: contentType || 'application/octet-stream',
        CacheControl: 'public, max-age=31536000, immutable',
      }),
    );
  }

  async objectExists(key: string): Promise<boolean> {
    if (!key || !this.bucket) return false;
    try {
      await this.s3.send(
        new HeadObjectCommand({
          Bucket: this.bucket,
          Key: key,
        }),
      );
      return true;
    } catch {
      return false;
    }
  }

  // Fetch an object stream and basic headers from storage
  async getObject(key: string) {
    try {
      const resp = await this.s3.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
      return {
        body: resp.Body as any, // Readable stream
        contentType: resp.ContentType || 'application/octet-stream',
        contentLength: resp.ContentLength,
        lastModified: resp.LastModified,
        etag: resp.ETag,
      };
    } catch (err: any) {
      // Fallback: if presign is disabled and endpoint/bucket are configured, try anonymous HTTP GET.
      // This helps local dev when keys are missing/invalid but bucket allows public reads.
      const code = err?.name || err?.Code || err?.code;
      const isCredsIssue = code === 'InvalidAccessKeyId' || code === 'SignatureDoesNotMatch' || code === 'CredentialsError' || code === 'AccessDenied';
      if (!this.presignDownload && this.endpoint && this.bucket && isCredsIssue) {
        const direct = `${this.endpoint.replace(/\/$/, '')}/${this.bucket}/${key}`;
        const u = new URL(direct);
        const mod = u.protocol === 'https:' ? https : http;
        return await new Promise<{ body: NodeJS.ReadableStream; contentType?: string; contentLength?: number; lastModified?: Date; etag?: string }>((resolve, reject) => {
          const req = mod.request(u, { method: 'GET' }, (resp) => {
            const status = resp.statusCode || 0;
            if (status >= 400) {
              reject(new Error(`Anonymous GET failed: ${status}`));
              return;
            }
            const contentType = resp.headers['content-type'] as string | undefined;
            const cl = resp.headers['content-length'] ? Number(resp.headers['content-length']) : undefined;
            const lm = resp.headers['last-modified'] ? new Date(String(resp.headers['last-modified'])) : undefined;
            const etag = resp.headers['etag'] as string | undefined;
            resolve({ body: resp, contentType, contentLength: cl, lastModified: lm, etag });
          });
          req.on('error', reject);
          req.end();
        });
      }
      throw err;
    }
  }
}
