import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/currency_constants.dart';
import '../config/env_config.dart';
import '../api/api_client.dart';
import 'locale_currency_detector.dart';
import '../models/locale_hints.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/profile/repository/profile_repository.dart';

/// Single source for the user's preferred fiat (from profile + location).
class UserCurrencyService extends ChangeNotifier {
  static final UserCurrencyService instance = UserCurrencyService._();
  UserCurrencyService._();

  static const _kCurrency = 'settings_currency';
  static const _kCountry = 'settings_country_code';
  static const _kWalletCurrency = 'wallet_default_currency';

  String _currency = LocaleCurrencyDetector.defaultCurrency;
  String? _countryCode;
  String? _timezone;

  String get preferredFiatCurrency => _currency;
  String? get countryCode => _countryCode;
  String? get timezone => _timezone;

  String get symbol => CurrencyConstants.symbolFor(_currency);
  String get label => CurrencyConstants.labelFor(_currency);

  /// Load from API profile (after login / register / OAuth).
  Future<void> applyFromProfile(Map<String, dynamic>? profile) async {
    if (profile == null) return;
    final settings = profile['settings'];
    String? currency;
    String? country;
    String? tz;

    if (settings is Map) {
      currency = settings['currency']?.toString();
      country = settings['countryCode']?.toString();
      tz = settings['timezone']?.toString();
    }
    currency ??= profile['preferredFiatCurrency']?.toString();
    country ??= profile['countryCode']?.toString();
    tz ??= profile['timezone']?.toString();

    if (currency != null && CurrencyConstants.displayCurrencyCodes.contains(currency.toUpperCase())) {
      _currency = currency.toUpperCase();
    }
    _countryCode = country?.toUpperCase();
    _timezone = tz;
    await _persistLocal();
    notifyListeners();
  }

  /// Device locale hints for auth endpoints (email, Google, Apple).
  LocaleHints deviceLocaleHints() => LocaleCurrencyDetector.detectFromDevice();

  /// After OAuth / register: sync device location if profile has no country yet.
  Future<void> ensureConfiguredFromDevice({bool forceIfMissingCountry = true}) async {
    final hints = deviceLocaleHints();
    if (!forceIfMissingCountry && _countryCode != null) return;
    await updateOnServer(
      countryCode: hints.countryCode,
      preferredFiatCurrency: hints.preferredFiatCurrency,
      timezone: hints.timezone,
      onlyIfCountryMissing: true,
    );
  }

  Future<void> updateOnServer({
    String? preferredFiatCurrency,
    String? countryCode,
    String? timezone,
    bool onlyIfCountryMissing = false,
  }) async {
    if (onlyIfCountryMissing && _countryCode != null && _countryCode!.isNotEmpty) {
      return;
    }
    try {
      final base = await EnvConfig.getBaseUrl();
      const storage = FlutterSecureStorage();
      final repo = ProfileRepository(ApiClient(base, storage).dio);
      final me = await repo.updateMe(
        preferredFiatCurrency: preferredFiatCurrency,
        countryCode: countryCode,
        timezone: timezone,
      );
      final profile = me['profile'];
      if (profile is Map) {
        await applyFromProfile(Map<String, dynamic>.from(profile));
      } else {
        if (preferredFiatCurrency != null &&
            CurrencyConstants.displayCurrencyCodes.contains(preferredFiatCurrency.toUpperCase())) {
          _currency = preferredFiatCurrency.toUpperCase();
        }
        if (countryCode != null) _countryCode = countryCode.toUpperCase();
        if (timezone != null) _timezone = timezone;
        await _persistLocal();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[UserCurrencyService] updateOnServer: $e');
    }
  }

  Future<void> loadFromLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final c = prefs.getString(_kCurrency) ?? prefs.getString(_kWalletCurrency);
    if (c != null && CurrencyConstants.displayCurrencyCodes.contains(c.toUpperCase())) {
      _currency = c.toUpperCase();
    }
    _countryCode = prefs.getString(_kCountry);
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrency, _currency);
    await prefs.setString(_kWalletCurrency, _currency);
    if (_countryCode != null) {
      await prefs.setString(_kCountry, _countryCode!);
    }
  }

  Future<void> setPreferredCurrency(String code) async {
    final upper = code.toUpperCase();
    if (!CurrencyConstants.displayCurrencyCodes.contains(upper)) return;
    _currency = upper;
    await _persistLocal();
    await updateOnServer(preferredFiatCurrency: upper, countryCode: _countryCode, timezone: _timezone);
    notifyListeners();
  }
}
