/** Supported display / payment fiat codes in the app. */
export const SUPPORTED_FIAT_CURRENCIES = [
  'NGN',
  'USD',
  'EUR',
  'GBP',
  'GHS',
  'KES',
  'ZAR',
  'JPY',
  'CAD',
] as const;

export type FiatCurrency = (typeof SUPPORTED_FIAT_CURRENCIES)[number];

const COUNTRY_TO_CURRENCY: Record<string, FiatCurrency> = {
  NG: 'NGN',
  GH: 'GHS',
  KE: 'KES',
  ZA: 'ZAR',
  US: 'USD',
  GB: 'GBP',
  CA: 'CAD',
  JP: 'JPY',
  // Eurozone (common)
  DE: 'EUR',
  FR: 'EUR',
  IT: 'EUR',
  ES: 'EUR',
  NL: 'EUR',
  BE: 'EUR',
  AT: 'EUR',
  IE: 'EUR',
  PT: 'EUR',
};

const DEFAULT_FIAT: FiatCurrency = 'NGN';

export interface LocaleHints {
  countryCode?: string;
  preferredFiatCurrency?: string;
  timezone?: string;
  acceptLanguage?: string;
  /** City/area label from device GPS or client (e.g. "Lagos, Lagos, Nigeria"). */
  location?: string;
}

export function normalizeCountryCode(code?: string | null): string | undefined {
  if (!code) return undefined;
  const upper = code.trim().toUpperCase();
  if (upper.length !== 2 || upper === 'XX' || upper === 'T1') return undefined;
  return upper;
}

export function normalizeFiatCurrency(code?: string | null): FiatCurrency | undefined {
  if (!code) return undefined;
  const upper = code.trim().toUpperCase();
  return (SUPPORTED_FIAT_CURRENCIES as readonly string[]).includes(upper)
    ? (upper as FiatCurrency)
    : undefined;
}

/** Infer ISO country from Accept-Language (e.g. en-NG → NG). */
export function countryFromAcceptLanguage(acceptLanguage?: string): string | undefined {
  if (!acceptLanguage) return undefined;
  const parts = acceptLanguage.split(',');
  for (const part of parts) {
    const tag = part.split(';')[0]?.trim();
    if (!tag) continue;
    const segments = tag.split('-');
    if (segments.length >= 2) {
      const region = normalizeCountryCode(segments[segments.length - 1]);
      if (region) return region;
    }
  }
  return undefined;
}

export function currencyForCountry(countryCode?: string): FiatCurrency {
  const cc = normalizeCountryCode(countryCode);
  if (cc && COUNTRY_TO_CURRENCY[cc]) return COUNTRY_TO_CURRENCY[cc];
  return DEFAULT_FIAT;
}

/**
 * Resolve preferred fiat + country for new profiles (email, Google, Apple).
 * Priority: explicit currency → explicit country → Accept-Language → default NGN.
 */
export function resolveProfileCurrency(hints?: LocaleHints): {
  preferredFiatCurrency: FiatCurrency;
  countryCode?: string;
  timezone?: string;
} {
  const explicitCurrency = normalizeFiatCurrency(hints?.preferredFiatCurrency);
  const country =
    normalizeCountryCode(hints?.countryCode) ??
    countryFromAcceptLanguage(hints?.acceptLanguage);

  const preferredFiatCurrency =
    explicitCurrency ?? currencyForCountry(country);

  return {
    preferredFiatCurrency,
    countryCode: country,
    timezone: hints?.timezone?.trim() || undefined,
  };
}

export function buildProfileSettings(profile: {
  preferredFiatCurrency?: string | null;
  countryCode?: string | null;
  timezone?: string | null;
  isProfilePublic?: boolean | null;
  showEmail?: boolean | null;
  showPhone?: boolean | null;
  showLocation?: boolean | null;
  allowDirectMessages?: boolean | null;
}) {
  return {
    isProfilePublic: profile.isProfilePublic ?? true,
    showEmail: profile.showEmail ?? false,
    showPhone: profile.showPhone ?? false,
    showLocation: profile.showLocation ?? true,
    allowDirectMessages: profile.allowDirectMessages ?? true,
    emailNotifications: true,
    pushNotifications: true,
    marketingEmails: false,
    language: 'en',
    currency: profile.preferredFiatCurrency ?? DEFAULT_FIAT,
    countryCode: profile.countryCode ?? null,
    timezone: profile.timezone ?? 'UTC',
  };
}
