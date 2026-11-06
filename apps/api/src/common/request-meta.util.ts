import { createHash } from 'crypto';
import type { Request } from 'express';

export type LoginMeta = {
  ip?: string;
  ua?: string;
  location?: string;
  deviceName?: string;
  deviceOs?: string;
  devicePlatform?: string;
  deviceFingerprint?: string;
};

function firstHeaderValue(value: string | string[] | undefined): string | undefined {
  if (!value) return undefined;
  return Array.isArray(value) ? value[0] : value;
}

/** Normalize IPv6-mapped IPv4 (::ffff:1.2.3.4 → 1.2.3.4). */
export function normalizeIpAddress(ip: string | undefined): string | undefined {
  if (!ip) return undefined;
  const trimmed = ip.trim();
  if (trimmed.startsWith('::ffff:')) {
    return trimmed.slice('::ffff:'.length);
  }
  return trimmed;
}

function parseForwardedFor(header: string | undefined): string | undefined {
  if (!header) return undefined;
  for (const part of header.split(',')) {
    const candidate = normalizeIpAddress(part.trim());
    if (candidate && !isPrivateOrNonPublicIp(candidate)) {
      return candidate;
    }
  }
  return undefined;
}

/** True for loopback, LAN, CGNAT (100.64/10), and link-local ranges. */
export function isPrivateOrNonPublicIp(ip: string | undefined): boolean {
  const normalized = normalizeIpAddress(ip);
  if (!normalized) return true;

  if (normalized === '::1' || normalized === '127.0.0.1') return true;
  if (normalized.startsWith('10.')) return true;
  if (normalized.startsWith('192.168.')) return true;
  if (normalized.startsWith('169.254.')) return true;
  if (normalized.startsWith('fe80:')) return true;

  if (normalized.startsWith('172.')) {
    const second = Number(normalized.split('.')[1]);
    if (second >= 16 && second <= 31) return true;
  }

  // Carrier-grade NAT / shared address space (common behind mobile carriers & cloud proxies).
  if (normalized.startsWith('100.')) {
    const second = Number(normalized.split('.')[1]);
    if (second >= 64 && second <= 127) return true;
  }

  return false;
}

/** Best-effort public client IP for security emails & auditing. */
export function extractClientIp(req: Request): string | undefined {
  const candidates = [
    firstHeaderValue(req.headers['cf-connecting-ip']),
    firstHeaderValue(req.headers['x-real-ip']),
    parseForwardedFor(firstHeaderValue(req.headers['x-forwarded-for'])),
    normalizeIpAddress(req.ip),
    normalizeIpAddress(req.socket?.remoteAddress),
  ];

  for (const candidate of candidates) {
    if (candidate && !isPrivateOrNonPublicIp(candidate)) {
      return candidate;
    }
  }

  return candidates.find(Boolean);
}

export function buildDeviceFingerprint(parts: {
  deviceName?: string;
  deviceOs?: string;
  devicePlatform?: string;
  ua?: string;
}): string {
  const payload = [
    parts.devicePlatform?.trim() ?? '',
    parts.deviceName?.trim() ?? '',
    parts.deviceOs?.trim() ?? '',
    (parts.ua ?? '').trim().toLowerCase(),
  ].join('|');
  return createHash('sha256').update(payload).digest('hex');
}

export function fingerprintFromAuditUa(ua?: string | null): string | null {
  if (!ua) return null;
  const tagged = ua.match(/^fp:([a-f0-9]{64})\|/);
  if (tagged) return tagged[1];
  return createHash('sha256').update(ua.trim().toLowerCase()).digest('hex');
}

export function formatAuditUa(meta?: LoginMeta): string | undefined {
  if (!meta?.deviceFingerprint && !meta?.ua) return undefined;
  if (meta.deviceFingerprint) {
    return `fp:${meta.deviceFingerprint}|${meta.ua ?? ''}`;
  }
  return meta.ua;
}

export function extractLoginMeta(
  req: Request,
  body?: { location?: string },
  device?: {
    deviceName: string;
    os: string;
    platform?: string;
    fingerprint: string;
  },
): LoginMeta {
  const ua = firstHeaderValue(req.headers['user-agent']);
  const ip = extractClientIp(req);
  const location = body?.location?.trim() || undefined;

  return {
    ip,
    ua,
    location,
    deviceName: device?.deviceName,
    deviceOs: device?.os,
    devicePlatform: device?.platform,
    deviceFingerprint: device?.fingerprint,
  };
}
