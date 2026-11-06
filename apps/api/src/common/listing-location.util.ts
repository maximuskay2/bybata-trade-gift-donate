import { BadRequestException } from '@nestjs/common';

/** Shared helpers for listing proximity search (trades, gifts, campaigns). */

export function requireListingLocation(location?: string | null): string {
  const trimmed = location?.trim();
  if (!trimmed) {
    throw new BadRequestException('Location is required');
  }
  return trimmed;
}

export function haversineMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const R = 6371000;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function extractListingCoords(
  metadata: unknown,
): { lat: number; lng: number } | null {
  if (!metadata || typeof metadata !== 'object') return null;
  const m = metadata as Record<string, unknown>;
  const lat = Number(m.latitude ?? m.lat);
  const lng = Number(m.longitude ?? m.lng ?? m.lon);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (lat === 0 && lng === 0) return null;
  return { lat, lng };
}

/** Split "City, State, Country" into match tokens including individual words. */
export function tokenizeLocationQuery(query: string): string[] {
  const tokens = new Set<string>();
  for (const part of query.split(/[,|/]+/)) {
    const p = part.trim().toLowerCase();
    if (p.length >= 2) tokens.add(p);
    for (const word of p.split(/\s+/)) {
      if (word.length >= 3) tokens.add(word);
    }
  }
  return [...tokens];
}

export function locationTextMatches(
  itemLocation: string | null | undefined,
  tokens: string[],
): boolean {
  if (!tokens.length) return true;
  const loc = (itemLocation ?? '').toLowerCase();
  if (!loc) return false;
  return tokens.some((t) => loc.includes(t));
}

export interface ListingGeoParams {
  lat?: number;
  lng?: number;
  radiusKm?: number;
  location?: string;
}

export function parseListingGeoParams(input: {
  lat?: string;
  lng?: string;
  lon?: string;
  radiusKm?: string;
  radius?: string;
  location?: string;
}): ListingGeoParams {
  const lat = parseFloat(input.lat ?? '');
  const lng = parseFloat(input.lng ?? input.lon ?? '');
  const radiusKm = parseFloat(input.radiusKm ?? input.radius ?? '50');
  return {
    lat: Number.isFinite(lat) ? lat : undefined,
    lng: Number.isFinite(lng) ? lng : undefined,
    radiusKm: Number.isFinite(radiusKm)
      ? Math.min(Math.max(radiusKm, 1), 500)
      : 50,
    location: input.location?.trim() || undefined,
  };
}

export function hasListingGeoFilter(opts: ListingGeoParams): boolean {
  return (
    (opts.lat != null && opts.lng != null) || !!(opts.location && opts.location.length > 0)
  );
}

export type ListingWithGeo<T> = T & {
  distanceMeters?: number;
};

export function applyListingGeoFilter<
  T extends { location?: string | null; metadata?: unknown },
>(items: T[], opts: ListingGeoParams): ListingWithGeo<T>[] {
  if (!hasListingGeoFilter(opts)) {
    return items.map((item) => ({ ...item }));
  }

  const radiusM = (opts.radiusKm ?? 50) * 1000;
  const hasCoords = opts.lat != null && opts.lng != null;
  const tokens = opts.location ? tokenizeLocationQuery(opts.location) : [];

  const enriched = items.map((item) => {
    const coords = extractListingCoords(item.metadata);
    let distanceMeters: number | undefined;
    if (hasCoords && coords) {
      distanceMeters = haversineMeters(opts.lat!, opts.lng!, coords.lat, coords.lng);
    }
    return { ...item, distanceMeters };
  });

  const filtered = enriched.filter((item) => {
    if (item.distanceMeters != null) {
      return item.distanceMeters <= radiusM;
    }
    if (tokens.length) {
      return locationTextMatches(item.location, tokens);
    }
    return false;
  });

  filtered.sort((a, b) => {
    if (a.distanceMeters != null && b.distanceMeters != null) {
      return a.distanceMeters - b.distanceMeters;
    }
    if (a.distanceMeters != null) return -1;
    if (b.distanceMeters != null) return 1;
    return 0;
  });

  return filtered;
}

export function paginateListingItems<T>(
  items: T[],
  page: number,
  size: number,
): { items: T[]; total: number; page: number; size: number } {
  const total = items.length;
  const start = (page - 1) * size;
  return {
    items: items.slice(start, start + size),
    total,
    page,
    size,
  };
}

export function buildListingMetadataWithCoords(
  existing: unknown,
  latitude?: number,
  longitude?: number,
): Record<string, unknown> {
  const base =
    existing && typeof existing === 'object'
      ? { ...(existing as Record<string, unknown>) }
      : {};
  if (latitude != null && Number.isFinite(latitude)) {
    base.latitude = latitude;
  }
  if (longitude != null && Number.isFinite(longitude)) {
    base.longitude = longitude;
  }
  return base;
}
