import '../services/location_service.dart';
import '../utils/profile_location_utils.dart';

/// Resolves a city/area label to store on the user profile at registration.
class SignupLocationService {
  SignupLocationService._();

  /// Fast path for sign-in — never blocks on GPS. Uses cached placemark only.
  static Future<String?> resolveForAuth() async {
    try {
      final cached = await LocationService.instance
          .getCachedPlacemark()
          .timeout(const Duration(milliseconds: 800));
      if (ProfileLocationUtils.isDisplayable(cached)) return cached!.trim();
    } catch (_) {}
    return null;
  }

  /// GPS placemark → cached placemark → country name from [countryCode].
  static Future<String?> resolveForRegistration({String? countryCode}) async {
    final cached = await LocationService.instance.getCachedPlacemark();
    if (ProfileLocationUtils.isDisplayable(cached)) return cached!.trim();

    if (await LocationService.instance.isGranted()) {
      final position = await LocationService.instance.getCurrentPosition();
      if (position != null) {
        final label = await LocationService.instance.resolvePlacemark(position);
        if (ProfileLocationUtils.isDisplayable(label)) return label!.trim();
      }
    }

    return ProfileLocationUtils.countryLabel(countryCode);
  }
}
