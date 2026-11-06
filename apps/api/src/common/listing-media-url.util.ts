/**
 * Builds client-fetchable URLs for listing media (CDN preferred, API object proxy fallback).
 */
export function buildListingMediaUrl(key: string | null | undefined): string | null {
  if (!key || typeof key !== 'string') return null;
  const trimmed = key.trim();
  if (!trimmed || trimmed.startsWith('/') || trimmed.startsWith('file:')) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }

  const cdn = (process.env.STORAGE_CDN_BASE_URL || '').trim().replace(/\/$/, '');
  if (cdn) {
    return `${cdn}/${trimmed}`;
  }

  const apiBase = (
    process.env.API_PUBLIC_BASE_URL ||
    process.env.APP_PUBLIC_URL ||
    process.env.API_PUBLIC_URL ||
    ''
  )
    .trim()
    .replace(/\/$/, '');
  if (!apiBase) return null;

  return `${apiBase}/v1/storage/object?key=${encodeURIComponent(trimmed)}&maxage=86400`;
}

export function variantKeysFor(sourceKey: string): { thumb: string; medium: string } {
  const dot = sourceKey.lastIndexOf('.');
  const base = dot > 0 ? sourceKey.slice(0, dot) : sourceKey;
  return {
    thumb: `${base}_thumb.jpg`,
    medium: `${base}_medium.jpg`,
  };
}

export function isLikelyVideoKey(key: string): boolean {
  const lower = key.toLowerCase();
  return (
    lower.endsWith('.mp4') ||
    lower.endsWith('.mov') ||
    lower.endsWith('.webm') ||
    lower.endsWith('.m4v')
  );
}

export function resolveFeedThumbnailKey(item: {
  thumbnailKey?: string | null;
  mediaType?: string | null;
  mediaKeys?: string[] | null;
}): string | null {
  const thumb = item.thumbnailKey?.trim();
  if (thumb) return thumb;
  const type = (item.mediaType || 'IMAGE').toString().toUpperCase();
  if (type === 'VIDEO') return null;
  const keys = item.mediaKeys;
  if (Array.isArray(keys) && keys.length > 0 && keys[0]?.trim()) {
    return keys[0].trim();
  }
  return null;
}

export function enrichListingItemForFeed<T extends Record<string, any>>(item: T): T {
  if (!item || typeof item !== 'object') return item;

  const thumbKey = resolveFeedThumbnailKey(item);
  const thumbnailUrl = buildListingMediaUrl(thumbKey);
  const previewImageUrl = thumbnailUrl;

  const enriched: Record<string, any> = {
    ...item,
    thumbnailUrl,
    previewImageUrl,
  };

  const owner = item.owner ?? item.giver ?? item.creator ?? item.founder;
  const avatarKey =
    owner?.profile?.avatarKey ??
    owner?.avatarKey ??
    item.ownerAvatarKey ??
    null;
  if (avatarKey) {
    enriched.ownerAvatarUrl = buildListingMediaUrl(String(avatarKey));
  }

  return enriched as T;
}

export function enrichListingPayloadForFeed<T extends { items?: any[] }>(payload: T): T {
  if (!payload?.items || !Array.isArray(payload.items)) return payload;
  return {
    ...payload,
    items: payload.items.map((it) => enrichListingItemForFeed(it)),
  };
}

export async function buildBatchMediaUrls(
  keys: string[],
): Promise<Record<string, string>> {
  const urls: Record<string, string> = {};
  for (const raw of keys) {
    const key = raw?.trim();
    if (!key || urls[key]) continue;
    const url = buildListingMediaUrl(key);
    if (url) urls[key] = url;
  }
  return urls;
}
