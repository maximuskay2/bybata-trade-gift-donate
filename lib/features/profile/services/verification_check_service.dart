import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../models/user_profile.dart';
import '../repository/profile_repository.dart';
import 'verification_progress_store.dart';

/// Service to check if the current user is verified (kycStatus == VERIFIED).
/// Used for withdrawal gates and other verified-only features.
class VerificationCheckService {
  /// Fresh check against `/v1/users/me?fresh=1` so KYC approvals are not blocked
  /// by a stale me-cache entry.
  static Future<bool> isUserVerified() async {
    try {
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, const FlutterSecureStorage());
      final me = await ProfileRepository(client.dio).me(fresh: true);
      return isVerifiedFromMePayload(me);
    } catch (_) {
      return false;
    }
  }

  /// Shared parser for `/v1/users/me` (and light) payloads.
  static bool isVerifiedFromMePayload(dynamic data) {
    if (data is! Map) return false;
    final map = Map<String, dynamic>.from(data);
    final profile = map['profile'];
    if (profile is Map) {
      final p = Map<String, dynamic>.from(profile);
      final kyc = (p['kycStatus'] ?? p['kyc_status'])?.toString().toUpperCase();
      if (kyc == 'VERIFIED') return true;

      final verification = p['verification'];
      if (verification is Map) {
        final status =
            (verification['status'] ?? verification['kycStatus'])?.toString().toLowerCase();
        if (status == 'verified') return true;
      }
    }
    if (map['isVerified'] == true) return true;
    return false;
  }

  /// Fetch current user profile for verification screen (e.g. when redirecting from withdrawal).
  static Future<UserProfile?> fetchCurrentProfile() async {
    try {
      final base = await EnvConfig.getBaseUrl();
      final client = ApiClient(base, const FlutterSecureStorage());
      final me = await ProfileRepository(client.dio).me(fresh: true);
      final profile = me['profile'] as Map<String, dynamic>?;
      final userData = me;
      if (profile == null) return null;
      final displayName = profile['displayName'] as String? ?? userData['email']?.toString() ?? 'User';
      final parts = displayName.split(' ');
      final emailVerifiedAt = userData['emailVerifiedAt'];
      final verificationMap = profile['verification'];
      final verification = verificationMap is Map
          ? VerificationStatus.fromJson(Map<String, dynamic>.from(verificationMap))
          : VerificationStatus.fromApiProfile(
              kycStatus: profile['kycStatus'] as String?,
              kycNote: profile['kycNote'] as String?,
              emailVerified: emailVerifiedAt != null,
              phoneVerified: profile['phoneVerifiedAt'] != null,
            );
      final userId = userData['id']?.toString() ?? '';
      await VerificationProgressStore.save(userId: userId, status: verification);
      return UserProfile(
        id: userId,
        firstName: parts.first,
        lastName: parts.length > 1 ? parts.skip(1).join(' ') : '',
        email: userData['email']?.toString() ?? '',
        phone: profile['phone'] as String?,
        bio: profile['bio'] as String?,
        avatar: profile['avatarKey'] as String?,
        location: null,
        occupation: null,
        interests: const [],
        stats: ProfileStats(
          totalTrades: 0,
          successfulTrades: 0,
          totalGifts: 0,
          totalDonations: 0,
          totalCommunities: 0,
          totalFollowers: 0,
          totalFollowing: 0,
          totalPosts: 0,
          totalLikes: 0,
          averageRating: 0.0,
          totalReviews: 0,
        ),
        trustScore: TrustScore(score: 0.0, level: 0, badges: [], lastUpdated: DateTime.now()),
        verification: verification,
        settings: ProfileSettings(),
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
