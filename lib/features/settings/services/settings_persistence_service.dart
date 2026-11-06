import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../notifications/api/notifications_api.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/repository/profile_repository.dart';
import '../../../core/services/user_currency_service.dart';

const kPrefLanguage = 'settings_language';
const kPrefCurrency = 'settings_currency';
const kPrefTimezone = 'settings_timezone';

/// Persists profile settings to API + local prefs.
class SettingsPersistenceService {
  SettingsPersistenceService._();
  static final SettingsPersistenceService instance =
      SettingsPersistenceService._();

  Future<ProfileRepository> _repo() async {
    final baseUrl = await EnvConfig.getBaseUrl();
    const storage = FlutterSecureStorage();
    final client = ApiClient(baseUrl, storage);
    return ProfileRepository(client.dio);
  }

  Future<NotificationsApi> _notificationsApi() async {
    final baseUrl = await EnvConfig.getBaseUrl();
    const storage = FlutterSecureStorage();
    final client = ApiClient(baseUrl, storage);
    return NotificationsApi(client);
  }

  Future<void> savePrivacy(ProfileSettings settings) async {
    final repo = await _repo();
    await repo.updatePrivacySettings(
      isProfilePublic: settings.isProfilePublic,
      showEmail: settings.showEmail,
      showPhone: settings.showPhone,
      showLocation: settings.showLocation,
      allowDirectMessages: settings.allowDirectMessages,
    );
  }

  Future<void> saveNotifications(ProfileSettings settings) async {
    final api = await _notificationsApi();
    await api.updateSettings(
      pushEnabled: settings.pushNotifications,
      emailEnabled: settings.emailNotifications,
    );
    final repo = await _repo();
    await repo.updateEmailPreferences(marketing: settings.marketingEmails);
  }

  Future<void> saveLocalPreferences(ProfileSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefLanguage, settings.language);
    await prefs.setString(kPrefCurrency, settings.currency);
    await prefs.setString(kPrefTimezone, settings.timezone);
  }

  Future<void> saveCurrencyPreference(ProfileSettings settings) async {
    await UserCurrencyService.instance.setPreferredCurrency(settings.currency);
    await saveLocalPreferences(settings);
  }

  Future<void> loadLocalPreferencesInto(ProfileSettings base) async {
    // Caller merges via copyWith after reading prefs in screen.
  }

  static Future<ProfileSettings> mergeStoredPrefs(ProfileSettings base) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var s = base;
      final lang = prefs.getString(kPrefLanguage);
      final currency = prefs.getString(kPrefCurrency);
      final timezone = prefs.getString(kPrefTimezone);
      if (lang != null && lang.isNotEmpty) s = s.copyWith(language: lang);
      if (currency != null && currency.isNotEmpty) {
        s = s.copyWith(currency: currency);
      }
      if (timezone != null && timezone.isNotEmpty) {
        s = s.copyWith(timezone: timezone);
      }
      return s;
    } catch (_) {
      return base;
    }
  }

  String? messageFromError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) return data['message']?.toString();
      return e.message;
    }
    return e.toString();
  }
}
