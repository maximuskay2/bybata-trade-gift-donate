/**
 * Utility to parse user agent / client headers and resolve login location.
 */

import { isPrivateOrNonPublicIp, normalizeIpAddress } from './request-meta.util';

export interface ClientDeviceHeaders {
  platform?: string;
  deviceName?: string;
  os?: string;
  appVersion?: string;
}

interface DeviceInfo {
  deviceName: string;
  os: string;
  browser: string;
}

export class DeviceInfoUtil {
  static parseClientHeaders(headers: Record<string, unknown>): ClientDeviceHeaders {
    const read = (key: string) => {
      const raw = headers[key] ?? headers[key.toLowerCase()];
      if (typeof raw === 'string' && raw.trim()) return raw.trim();
      if (Array.isArray(raw) && typeof raw[0] === 'string' && raw[0].trim()) {
        return raw[0].trim();
      }
      return undefined;
    };

    return {
      platform: read('x-bybata-platform'),
      deviceName: read('x-bybata-device-name'),
      os: read('x-bybata-device-os'),
      appVersion: read('x-bybata-app-version'),
    };
  }

  /** Prefer explicit mobile client headers; fall back to user-agent parsing. */
  static resolveDeviceInfo(
    ua: string | undefined,
    client?: ClientDeviceHeaders,
  ): DeviceInfo {
    if (client?.deviceName || client?.platform || client?.os) {
      const platform = client.platform ?? 'Mobile';
      const model = client.deviceName ?? platform;
      const os = client.os ?? this.parseUserAgent(ua).os;
      const appLabel = client.appVersion
        ? `Bybata ${client.appVersion}`
        : 'Bybata App';
      return {
        deviceName: `${model} (${appLabel})`,
        os,
        browser: appLabel,
      };
    }

    return this.parseUserAgent(ua);
  }

  /**
   * Parse user agent string to extract device information.
   */
  static parseUserAgent(ua: string | undefined): DeviceInfo {
    if (!ua) {
      return {
        deviceName: 'Unknown device',
        os: 'Unknown OS',
        browser: 'Unknown client',
      };
    }

    const lower = ua.toLowerCase();

    // Bybata mobile app user agent: Bybata/1.0 (iOS; Version 17.2) Dart/Flutter
    const bybataMatch = ua.match(/Bybata\/[\d.]+ \(([^;)]+);?\s*([^)]*)\)/i);
    if (bybataMatch) {
      const platform = bybataMatch[1]?.trim() || 'Mobile';
      const osDetail = bybataMatch[2]?.trim();
      const os = osDetail ? `${platform} ${osDetail}` : platform;
      const label = platform.includes('iOS')
        ? 'iPhone'
        : platform.includes('Android')
          ? 'Android phone'
          : platform;
      return {
        deviceName: `${label} (Bybata App)`,
        os,
        browser: 'Bybata App',
      };
    }

    // Flutter / Dart HTTP clients (no custom headers)
    if (lower.includes('dart/') || lower === 'okhttp') {
      const os = lower.includes('android')
        ? 'Android'
        : lower.includes('iphone') || lower.includes('ios')
          ? 'iOS'
          : 'Mobile';
      return {
        deviceName: `${os} phone (Bybata App)`,
        os,
        browser: 'Bybata App',
      };
    }

    // Detect OS
    let os = 'Unknown OS';
    if (ua.includes('Windows NT 10.0')) os = 'Windows 10';
    else if (ua.includes('Windows NT 6.3')) os = 'Windows 8.1';
    else if (ua.includes('Windows NT 6.2')) os = 'Windows 8';
    else if (ua.includes('Windows NT 6.1')) os = 'Windows 7';
    else if (ua.includes('Windows')) os = 'Windows';
    else if (ua.includes('Mac OS X')) {
      const version = ua.match(/Mac OS X (\d+[._]\d+[._]?\d*)/);
      os = version ? `macOS ${version[1].replace(/_/g, '.')}` : 'macOS';
    } else if (ua.includes('Android')) {
      const version = ua.match(/Android (\d+(?:\.\d+)?)/);
      os = version ? `Android ${version[1]}` : 'Android';
    } else if (ua.includes('iPhone') || ua.includes('iPad')) {
      const version = ua.match(/OS (\d+_\d+(?:_\d+)?)/);
      os = version ? `iOS ${version[1].replace(/_/g, '.')}` : 'iOS';
    } else if (ua.includes('Linux')) os = 'Linux';
    else if (ua.includes('CrOS')) os = 'Chrome OS';

    // Detect Browser
    let browser = 'Unknown Browser';
    if (ua.includes('Edg/')) browser = 'Microsoft Edge';
    else if (ua.includes('Chrome/') && !ua.includes('Edg')) browser = 'Chrome';
    else if (ua.includes('Safari/') && !ua.includes('Chrome')) browser = 'Safari';
    else if (ua.includes('Firefox/')) browser = 'Firefox';
    else if (ua.includes('Opera/') || ua.includes('OPR/')) browser = 'Opera';
    else if (ua.includes('MSIE') || ua.includes('Trident/')) browser = 'Internet Explorer';

    // Detect Device Type
    let deviceType = 'Desktop';
    if (ua.includes('Mobile') || ua.includes('Android')) deviceType = 'Mobile';
    else if (ua.includes('Tablet') || ua.includes('iPad')) deviceType = 'Tablet';

    let deviceName = deviceType;
    if (ua.includes('iPhone')) deviceName = 'iPhone';
    else if (ua.includes('iPad')) deviceName = 'iPad';
    else if (ua.includes('Android')) {
      const model = ua.match(/Android[^;]+; ([^)]+)\)/);
      deviceName = model ? model[1].trim() : 'Android device';
    } else if (ua.includes('Macintosh')) deviceName = 'Mac';
    else if (ua.includes('Windows')) deviceName = 'Windows PC';
    else if (ua.includes('Linux')) deviceName = 'Linux PC';

    return {
      deviceName: `${deviceName} (${browser})`,
      os,
      browser,
    };
  }

  /**
   * Get location from IP address using a free IP geolocation service.
   */
  static async getLocationFromIP(ip: string | undefined): Promise<{
    city: string;
    country: string;
    region: string;
  }> {
    const normalized = normalizeIpAddress(ip);
    if (!normalized || isPrivateOrNonPublicIp(normalized)) {
      return {
        city: 'Unknown',
        country: 'Unknown',
        region: 'Unknown',
      };
    }

    try {
      const response = await fetch(
        `https://ip-api.com/json/${encodeURIComponent(normalized)}?fields=status,message,country,regionName,city`,
        { signal: AbortSignal.timeout(4000) },
      );
      const data = await response.json();

      if (data.status === 'success') {
        return {
          city: data.city || 'Unknown',
          country: data.country || 'Unknown',
          region: data.regionName || 'Unknown',
        };
      }
    } catch (error) {
      console.error('Failed to get location from IP:', error);
    }

    return {
      city: 'Unknown',
      country: 'Unknown',
      region: 'Unknown',
    };
  }

  /**
   * Human-readable location for login alert emails.
   * Prefers the client's GPS/city label; avoids misleading private/CGNAT IPs.
   */
  static formatLoginLocation(opts: {
    geo: { city: string; country: string; region: string };
    ip?: string;
    clientLocation?: string;
  }): string {
    const client = opts.clientLocation?.trim();
    if (client) return client;

    const parts: string[] = [];
    if (opts.geo.city !== 'Unknown') parts.push(opts.geo.city);
    if (opts.geo.region !== 'Unknown' && opts.geo.region !== opts.geo.city) {
      parts.push(opts.geo.region);
    }
    if (opts.geo.country !== 'Unknown') parts.push(opts.geo.country);
    if (parts.length > 0) return parts.join(', ');

    const normalized = normalizeIpAddress(opts.ip);
    if (normalized && !isPrivateOrNonPublicIp(normalized)) {
      return 'Unknown area';
    }

    return 'Location unavailable';
  }

  /** @deprecated Use formatLoginLocation for emails. */
  static formatLocation(
    location: { city: string; country: string; region: string },
    ip: string,
  ): string {
    return this.formatLoginLocation({ geo: location, ip });
  }
}
