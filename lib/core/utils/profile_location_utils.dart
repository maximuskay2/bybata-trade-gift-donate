/// Helpers for resolving and displaying profile city/area labels.
class ProfileLocationUtils {
  ProfileLocationUtils._();

  static const _countryNames = {
    'NG': 'Nigeria',
    'GH': 'Ghana',
    'KE': 'Kenya',
    'ZA': 'South Africa',
    'US': 'United States',
    'GB': 'United Kingdom',
    'CA': 'Canada',
    'JP': 'Japan',
    'DE': 'Germany',
    'FR': 'France',
    'IT': 'Italy',
    'ES': 'Spain',
    'NL': 'Netherlands',
    'BE': 'Belgium',
    'AT': 'Austria',
    'IE': 'Ireland',
    'PT': 'Portugal',
    'AE': 'United Arab Emirates',
    'IN': 'India',
  };

  static bool isDisplayable(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (RegExp(r'^unknown(\b|,|\s|\()', caseSensitive: false).hasMatch(trimmed)) {
      return false;
    }
    if (RegExp(r'^local network$', caseSensitive: false).hasMatch(trimmed)) {
      return false;
    }
    return true;
  }

  static String? countryLabel(String? countryCode) {
    if (countryCode == null || countryCode.trim().length != 2) return null;
    final cc = countryCode.trim().toUpperCase();
    return _countryNames[cc] ?? cc;
  }

  /// Picks the best public location label from API profile fields.
  static String? fromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final location = profile['location'] as String?;
    if (isDisplayable(location)) return location!.trim();
    return countryLabel(profile['countryCode'] as String?);
  }
}
