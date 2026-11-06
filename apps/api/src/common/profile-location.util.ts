import { DeviceInfoUtil } from './device-info.util';
import { normalizeCountryCode } from './currency.util';

/** Common ISO country codes → display name for profile fallback. */
const COUNTRY_NAMES: Record<string, string> = {
  NG: 'Nigeria',
  GH: 'Ghana',
  KE: 'Kenya',
  ZA: 'South Africa',
  US: 'United States',
  GB: 'United Kingdom',
  CA: 'Canada',
  JP: 'Japan',
  DE: 'Germany',
  FR: 'France',
  IT: 'Italy',
  ES: 'Spain',
  NL: 'Netherlands',
  BE: 'Belgium',
  AT: 'Austria',
  IE: 'Ireland',
  PT: 'Portugal',
  AE: 'United Arab Emirates',
  IN: 'India',
};

/** Strip placeholder / unusable location strings. */
export function sanitizeProfileLocation(raw?: string | null): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (/^unknown(\b|,|\s|\()/i.test(trimmed)) return null;
  if (/^local network$/i.test(trimmed)) return null;
  return trimmed;
}

export function countryCodeToDisplayName(code?: string | null): string | null {
  const cc = normalizeCountryCode(code);
  if (!cc) return null;
  return COUNTRY_NAMES[cc] ?? cc;
}

export function formatGeoForProfile(geo: {
  city: string;
  country: string;
  region: string;
}): string | null {
  const city = geo.city?.trim();
  const country = geo.country?.trim();
  const region = geo.region?.trim();

  if (city && city !== 'Unknown' && city !== 'Local Network') {
    if (country && country !== 'Unknown' && country !== city) {
      return `${city}, ${country}`;
    }
    return city;
  }

  if (region && region !== 'Unknown' && region !== 'Local Network') {
    if (country && country !== 'Unknown') return `${region}, ${country}`;
    return region;
  }

  if (country && country !== 'Unknown') return country;
  return null;
}

/** Best-effort city/area for new profiles: client GPS label → IP geo → country name. */
export async function resolveRegistrationLocation(opts: {
  clientLocation?: string | null;
  ip?: string;
  countryCode?: string | null;
}): Promise<string | null> {
  const fromClient = sanitizeProfileLocation(opts.clientLocation);
  if (fromClient) return fromClient;

  const geo = await DeviceInfoUtil.getLocationFromIP(opts.ip);
  const fromIp = formatGeoForProfile(geo);
  if (fromIp) return fromIp;

  return countryCodeToDisplayName(opts.countryCode);
}

export function profileHasUsableLocation(location?: string | null): boolean {
  return sanitizeProfileLocation(location) != null;
}
