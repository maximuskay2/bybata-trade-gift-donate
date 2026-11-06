import { AdMediaType } from '@prisma/client';
import { StorageService } from '../storage/storage.service';

export function pickAdThumbnailKey(
  mediaType: AdMediaType | string,
  mediaKeys: string[],
  videoKey: string | null,
): string | null {
  const keys = (mediaKeys ?? []).map((k) => k?.trim()).filter(Boolean);
  if (mediaType === AdMediaType.VIDEO || mediaType === 'VIDEO') {
    const vk = videoKey?.trim();
    return vk || keys[0] || null;
  }
  return keys[0] ?? null;
}

export async function resolveAdThumbnailUrl(
  storage: StorageService,
  mediaType: AdMediaType | string,
  mediaKeys: string[],
  videoKey: string | null,
): Promise<string | null> {
  const key = pickAdThumbnailKey(mediaType, mediaKeys, videoKey);
  if (!key) return null;

  const presign =
    (process.env.STORAGE_PRESIGN_DOWNLOAD ?? 'true').toLowerCase() === 'true';
  if (!presign) {
    const base = (
      process.env.API_PUBLIC_BASE_URL ||
      process.env.APP_PUBLIC_URL ||
      ''
    )
      .trim()
      .replace(/\/$/, '');
    if (base) {
      return `${base}/v1/storage/object?key=${encodeURIComponent(key)}`;
    }
  }

  const { url } = await storage.createDownloadUrl(key);
  return url ?? null;
}
