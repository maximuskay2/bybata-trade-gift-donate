import { BadRequestException } from '@nestjs/common';

const MAX_URL_LENGTH = 2048;

export function normalizeDestinationUrl(raw?: string | null): string | null {
  const trimmed = raw?.trim();
  if (!trimmed) return null;
  if (trimmed.length > MAX_URL_LENGTH) return null;

  let candidate = trimmed;
  if (!/^https?:\/\//i.test(candidate)) {
    candidate = `https://${candidate}`;
  }

  try {
    const parsed = new URL(candidate);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return null;
    }
    return parsed.toString();
  } catch {
    return null;
  }
}

export function requireDestinationUrl(raw?: string | null): string {
  const normalized = normalizeDestinationUrl(raw);
  if (!normalized) {
    throw new BadRequestException(
      'A valid destination link is required (use http:// or https://)',
    );
  }
  return normalized;
}

export function optionalDestinationUrl(raw?: string | null): string | null {
  if (!raw?.trim()) return null;
  const normalized = normalizeDestinationUrl(raw);
  if (!normalized) {
    throw new BadRequestException(
      'Invalid destination link. Use a full URL starting with http:// or https://',
    );
  }
  return normalized;
}
