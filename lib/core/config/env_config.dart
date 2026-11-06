import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnvConfig {
  static const String _kBaseUrl = 'api_base_url';
  // Default API for production (release builds)
  static const String defaultBaseUrl = 'https://bybataapi-production.up.railway.app';
  // Default API for development/debug builds (host machine). On Android emulator,
  // the host's localhost:3000 is accessible via 10.0.2.2:3000.
  static const String defaultDevBaseUrl = 'http://10.0.2.2:3000';

  /// Platform-aware dev API base. iOS simulator uses localhost; Android emulator
  /// uses 10.0.2.2 to reach the host machine.
  static String get defaultDevBaseUrlForPlatform {
    if (kIsWeb) return 'http://localhost:3000';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return defaultDevBaseUrl;
      case TargetPlatform.iOS:
        return 'http://localhost:3000';
      default:
        return 'http://localhost:3000';
    }
  }

  /// Compile-time override. Pass with:
  ///   flutter run --dart-define=API_BASE_URL=https://bybataapi-production.up.railway.app
  /// Wins over every other source (debug/profile/release alike).
  static const String _overrideBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Public accessor for the compile-time override. Empty when not set.
  static String get overrideBaseUrl => _overrideBaseUrl;
  static bool get hasOverride => _overrideBaseUrl.isNotEmpty;

  static const String googleMapsApiKey = '';
  static const String mapboxAccessToken = '';
  /// Web Client ID for Google Sign-In backend verification. Must match
  /// GOOGLE_CLIENT_ID_WEB on the API. Get from Firebase Console > Project Settings >
  /// Your apps > Web app, or Google Cloud Console > Credentials.
  static const String googleWebClientId =
      '667403716631-4makg0v5j26b3u50lsbbo4u1scms60ne.apps.googleusercontent.com';
  /// iOS OAuth client ID (GoogleService-Info.plist CLIENT_ID). Required on iOS
  /// so Google Sign-In can return an ID token for backend verification.
  static const String googleIosClientId =
      '667403716631-o957fc8dbomfnkksp0od2r02t9j6bdpo.apps.googleusercontent.com';

  /// OAuth client used for Android browser sign-in (same iOS client — already
  /// registered with the reversed URL scheme in Google Cloud / Firebase).
  static String get googleOAuthClientId => googleIosClientId;

  /// Reversed OAuth client ID used as the redirect scheme (matches iOS Info.plist).
  static String get googleOAuthCallbackScheme {
    final prefix =
        googleOAuthClientId.replaceAll('.apps.googleusercontent.com', '');
    return 'com.googleusercontent.apps.$prefix';
  }

  /// Redirect URI registered for the iOS OAuth client in Google Cloud Console.
  static String get googleOAuthRedirectUri =>
      '$googleOAuthCallbackScheme:/oauth2redirect';

  static bool isLocalUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('localhost') ||
        lower.contains('127.0.0.1') ||
        lower.contains('10.0.2.2') || // Android emulator host machine
        lower.startsWith('http://192.168.') ||
        lower.startsWith('https://192.168.');
  }

  static Future<String> getBaseUrl() async {
    // 1. Compile-time override always wins.
    if (_overrideBaseUrl.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kBaseUrl) != _overrideBaseUrl) {
        await prefs.setString(_kBaseUrl, _overrideBaseUrl);
      }
      return _overrideBaseUrl;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kBaseUrl);

    // 2. Profile and release use the production API by default. Respect any
    //    non-local override the user has explicitly chosen.
    if (!kDebugMode) {
      if (stored == null || isLocalUrl(stored)) {
        await prefs.setString(_kBaseUrl, defaultBaseUrl);
        return defaultBaseUrl;
      }
      return stored;
    }

    // 3. Debug builds: respect a stored URL (e.g. production chosen in settings).
    //    Only fall back to the platform dev default when nothing is saved yet.
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    final devDefault = defaultDevBaseUrlForPlatform;
    await prefs.setString(_kBaseUrl, devDefault);
    return devDefault;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, url);
  }

  static List<EnvProfile> profiles() {
    // In profile/release builds, expose all environments including staging/production.
    if (!kDebugMode) {
      return const [
        EnvProfile(name: 'Localhost', url: defaultDevBaseUrl),
        EnvProfile(name: 'Local (LAN)', url: 'http://192.168.1.44:3000'),
        EnvProfile(name: 'Staging', url: 'https://api.staging.bybata.app'),
        EnvProfile(name: 'Production', url: defaultBaseUrl),
      ];
    }

    // In debug/emulator builds, only expose dev/local APIs.
    return const [
      // For Android emulator, host machine's localhost is 10.0.2.2
      EnvProfile(name: 'Localhost', url: defaultDevBaseUrl),
      EnvProfile(name: 'Local (LAN)', url: 'http://192.168.1.44:3000'),
    ];
  }
}

class EnvProfile {
  final String name;
  final String url;
  const EnvProfile({required this.name, required this.url});
}
