import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { StorageService } from './storage.service';
import Jimp from 'jimp';
import type { MediaAsset } from '@prisma/client';
import {
  isLikelyVideoKey,
  variantKeysFor,
} from '../common/listing-media-url.util';
import { ListingMediaType } from '@prisma/client';

export type MediaDomain = 'trades' | 'gifts' | 'donations' | 'ads' | 'profiles' | 'communities';

@Injectable()
export class MediaService {
  private readonly logger = new Logger(MediaService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  /**
   * Ensure we have a MediaAsset row (with phash/size when possible) for each key.
   */
  async ensureMediaAssetsForKeys(ownerId: string, domain: MediaDomain, keys: string[]): Promise<MediaAsset[]> {
    const results: MediaAsset[] = [];
    for (const key of keys) {
      if (!key) continue;
      // Derive ownerId from key path if missing
      let effectiveOwnerId = ownerId;
      const parts = key.split('/');
      if (parts.length >= 2 && !effectiveOwnerId) {
        effectiveOwnerId = parts[1];
      }
      const asset = await this.ensureMediaAsset(effectiveOwnerId, domain, key);
      if (asset) results.push(asset);
    }
    return results;
  }

  private async ensureMediaAsset(ownerId: string, domain: MediaDomain, key: string): Promise<MediaAsset | null> {
    if (!key) return null;

    let asset = await this.prisma.mediaAsset.findUnique({ where: { key } }).catch(() => null);
    if (asset && asset.phash && asset.width !== null && asset.height !== null) {
      return asset;
    }

    try {
      const startTime = Date.now();
      const object = await this.storage.getObject(key);
      const chunks: Buffer[] = [];
      await new Promise<void>((resolve, reject) => {
        const stream = object.body as NodeJS.ReadableStream;
        stream.on('data', (chunk: Buffer) => chunks.push(chunk));
        stream.on('end', () => resolve());
        stream.on('error', (err) => reject(err));
      });
      const buffer = Buffer.concat(chunks);
      
      // Log performance metrics for pHash computation
      const jimp_start = Date.now();
      const image = await Jimp.read(buffer);
      const imageLoadDuration = Date.now() - jimp_start;
      
      const width = image.getWidth();
      const height = image.getHeight();
      
      // Compute perceptual hash (this is the performance-critical operation)
      const phash_start = Date.now();
      const phash = image.hash(); // Jimp's perceptual hash
      const phashDuration = Date.now() - phash_start;
      
      const totalDuration = Date.now() - startTime;

      // Log performance metrics
      this.logger.debug(
        `pHash computed for ${key}: ` +
        `imageLoad=${imageLoadDuration}ms, ` +
        `phash=${phashDuration}ms, ` +
        `total=${totalDuration}ms, ` +
        `dimensions=${width}x${height}`,
      );

      if (asset) {
        asset = await this.prisma.mediaAsset.update({
          where: { id: asset.id },
          data: {
            ownerId,
            domain,
            phash,
            width,
            height,
          },
        });
      } else {
        asset = await this.prisma.mediaAsset.create({
          data: {
            key,
            ownerId,
            domain,
            phash,
            width,
            height,
          },
        });
      }
      return asset;
    } catch (err: any) {
      this.logger.warn(`Failed to compute media metadata for key=${key}: ${err?.message || err}`);
      // Ensure at least a stub exists so we don't retry endlessly
      if (!asset) {
        asset = await this.prisma.mediaAsset.create({
          data: {
            key,
            ownerId,
            domain,
          },
        });
      }
      return asset;
    }
  }

  private hammingDistance(a: string, b: string): number {
    const len = Math.min(a.length, b.length);
    let dist = 0;
    for (let i = 0; i < len; i++) {
      if (a[i] !== b[i]) dist++;
    }
    return dist + Math.abs(a.length - b.length);
  }

  /**
   * Given a list of newly uploaded keys for a user/domain, return a de-duplicated
   * list of keys based on perceptual hash. Keys whose pHash is within `threshold`
   * of an already-kept key are treated as duplicates and dropped.
   */
  async dedupeMediaKeys(
    ownerId: string,
    domain: MediaDomain,
    keys: string[],
    threshold = Number(process.env.MEDIA_PHASH_THRESHOLD || 4),
  ): Promise<{ kept: string[]; dropped: string[] }> {
    if (!keys || keys.length === 0) return { kept: [], dropped: [] };

    const startTime = Date.now();
    const assets = await this.ensureMediaAssetsForKeys(ownerId, domain, keys);
    const kept: string[] = [];
    const dropped: string[] = [];

    let comparisons = 0;
    for (const asset of assets) {
      if (!asset?.key) continue;
      const currentHash = asset.phash;
      if (!currentHash) {
        // No hash yet, keep it
        kept.push(asset.key);
        continue;
      }

      let isDuplicate = false;
      for (const keptKey of kept) {
        const existing = assets.find((a) => a.key === keptKey);
        if (!existing?.phash) continue;
        comparisons++;
        const distance = this.hammingDistance(currentHash, existing.phash);
        if (distance <= threshold) {
          isDuplicate = true;
          break;
        }
      }

      if (isDuplicate) {
        dropped.push(asset.key);
      } else {
        kept.push(asset.key);
      }
    }

    if (dropped.length > 0) {
      const duration = Date.now() - startTime;
      this.logger.log(
        `Media dedup: owner=${ownerId} domain=${domain} kept=${kept.length} dropped=${dropped.length} ` +
        `comparisons=${comparisons} duration=${duration}ms threshold=${threshold}`,
      );
    }

    return { kept, dropped };
  }

  /**
   * Generates `_thumb.jpg` (400px) and `_medium.jpg` (800px) variants for feed cards.
   * Idempotent — skips work when thumb already exists in storage.
   */
  async ensureListingImageVariants(
    _ownerId: string,
    _domain: MediaDomain,
    sourceKey: string,
  ): Promise<{ thumbKey: string; mediumKey: string } | null> {
    const key = sourceKey?.trim();
    if (!key || isLikelyVideoKey(key)) return null;

    const { thumb, medium } = variantKeysFor(key);
    if (await this.storage.objectExists(thumb)) {
      return { thumbKey: thumb, mediumKey: medium };
    }

    try {
      const object = await this.storage.getObject(key);
      const chunks: Buffer[] = [];
      await new Promise<void>((resolve, reject) => {
        const stream = object.body as NodeJS.ReadableStream;
        stream.on('data', (chunk: Buffer) => chunks.push(chunk));
        stream.on('end', () => resolve());
        stream.on('error', (err) => reject(err));
      });
      const buffer = Buffer.concat(chunks);
      const image = await Jimp.read(buffer);

      const thumbImg = image.clone().resize(400, Jimp.AUTO).quality(82);
      const mediumImg = image.clone().resize(800, Jimp.AUTO).quality(85);
      const thumbBuf = await thumbImg.quality(82).getBufferAsync(Jimp.MIME_JPEG);
      const mediumBuf = await mediumImg.quality(85).getBufferAsync(Jimp.MIME_JPEG);

      await this.storage.putObjectKey(thumb, thumbBuf, 'image/jpeg');
      await this.storage.putObjectKey(medium, mediumBuf, 'image/jpeg');

      this.logger.debug(`Generated listing variants for ${key} -> ${thumb}`);
      return { thumbKey: thumb, mediumKey: medium };
    } catch (err: any) {
      this.logger.warn(
        `Failed to generate listing variants for key=${key}: ${err?.message || err}`,
      );
      return null;
    }
  }

  async resolveListingThumbnailKey(
    ownerId: string,
    domain: MediaDomain,
    media: {
      mediaType: ListingMediaType;
      mediaKeys: string[];
      videoKey: string | null;
    },
    explicitThumb?: string | null,
  ): Promise<string | null> {
    if (media.mediaType === ListingMediaType.VIDEO) {
      const poster = explicitThumb?.trim() || null;
      if (!poster) return null;
      const variants = await this.ensureListingImageVariants(ownerId, domain, poster);
      return variants?.thumbKey ?? poster;
    }
    const primary = media.mediaKeys[0]?.trim();
    if (!primary) return null;
    const variants = await this.ensureListingImageVariants(ownerId, domain, primary);
    return variants?.thumbKey ?? primary;
  }
}
