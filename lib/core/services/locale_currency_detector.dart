import 'dart:ui';

import '../constants/currency_constants.dart';
import '../models/locale_hints.dart';

/// Maps device locale (+ optional GPS country) to fiat currency for signup / OAuth.
class LocaleCurrencyDetector {
  LocaleCurrencyDetector._();

  static const Map<String, String> _countryToCurrency = {
    'NG': 'NGN',
    'GH': 'GHS',
    'KE': 'KES',
    'ZA': 'ZAR',
    'US': 'USD',
    'GB': 'GBP',
    'CA': 'CAD',
    'JP': 'JPY',
    'DE': 'EUR',
    'FR': 'EUR',
    'IT': 'EUR',
    'ES': 'EUR',
    'NL': 'EUR',
    'BE': 'EUR',
    'AT': 'EUR',
    'IE': 'EUR',
    'PT': 'EUR',
  };

  static const String defaultCurrency = 'NGN';

  /// Primary detection from [PlatformDispatcher] locale (no permissions).
  static LocaleHints detectFromDevice() {
    final locale = PlatformDispatcher.instance.locale;
    final country = locale.countryCode?.toUpperCase();
    final currency = currencyForCountry(country);
    return LocaleHints(
      countryCode: country,
      preferredFiatCurrency: currency,
      timezone: DateTime.now().timeZoneName,
    );
  }

  /// Optional GPS country override (call only when location permission already granted).
  static LocaleHints withCountryOverride(LocaleHints base, String? isoCountryCode) {
    if (isoCountryCode == null || isoCountryCode.length != 2) return base;
    final cc = isoCountryCode.toUpperCase();
    return LocaleHints(
      countryCode: cc,
      preferredFiatCurrency: currencyForCountry(cc),
      timezone: base.timezone,
    );
  }

  static String currencyForCountry(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return defaultCurrency;
    final cc = countryCode.toUpperCase();
    final mapped = _countryToCurrency[cc];
    if (mapped != null && CurrencyConstants.displayCurrencyCodes.contains(mapped)) {
      return mapped;
    }
    return defaultCurrency;
  }

  static String? countryFromPlacemarkIso(String? iso) {
    if (iso == null || iso.length != 2) return null;
    return iso.toUpperCase();
  }
}
