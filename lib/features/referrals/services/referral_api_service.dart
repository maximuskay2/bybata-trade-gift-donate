import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';

/// On Android emulators, localhost in invite URLs points at the device, not the dev machine.
String _normalizeReferralLinkForDevice(String url) {
  if (url.isEmpty) return url;
  if (kIsWeb) return url;
  if (defaultTargetPlatform != TargetPlatform.android) return url;
  try {
    final uri = Uri.parse(url);
    if (uri.host != 'localhost' && uri.host != '127.0.0.1') return url;
    return uri.replace(host: '10.0.2.2').toString();
  } catch (_) {
    return url;
  }
}

/// API service for referral endpoints.
class ReferralApiService {
  ReferralApiService(this._apiClient);

  final ApiClient _apiClient;

  static Future<ReferralApiService> create() async {
    final baseUrl = await EnvConfig.getBaseUrl();
    final storage = const FlutterSecureStorage();
    final apiClient = ApiClient(baseUrl, storage);
    return ReferralApiService(apiClient);
  }

  /// GET /v1/referrals/me - Fetch current user's referral stats (requires auth).
  Future<ReferralStats> getMyReferralStats() async {
    final response = await _apiClient.get('/v1/referrals/me');
    final data = response.data as Map<String, dynamic>;
    return ReferralStats.fromJson(data);
  }

  /// GET /v1/referrals/lookup?code= - Public lookup to validate a referral code.
  Future<ReferralLookupResult?> lookupReferralCode(String code) async {
    if (code.trim().isEmpty) return null;
    try {
      final response = await _apiClient.get(
        '/v1/referrals/lookup',
        queryParameters: {'code': code.trim()},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return null;
      return ReferralLookupResult(
        referrerId: data['referrerId'] as String? ?? '',
        displayName: data['displayName'] as String? ?? 'User',
      );
    } catch (_) {
      return null;
    }
  }
}

class ReferralStats {
  final String referralCode;
  final String referralLink;
  final int totalReferrals;
  final int totalKarmaEarned;
  final double totalBycEarned;
  final List<ReferralItem> referrals;

  ReferralStats({
    required this.referralCode,
    required this.referralLink,
    required this.totalReferrals,
    required this.totalKarmaEarned,
    required this.totalBycEarned,
    required this.referrals,
  });

  factory ReferralStats.fromJson(Map<String, dynamic> json) {
    final refs = (json['referrals'] as List<dynamic>?) ?? [];
    return ReferralStats(
      referralCode: json['referralCode'] as String? ?? '',
      referralLink: _normalizeReferralLinkForDevice(
        json['referralLink'] as String? ?? '',
      ),
      totalReferrals: (json['totalReferrals'] as num?)?.toInt() ?? 0,
      totalKarmaEarned: (json['totalKarmaEarned'] as num?)?.toInt() ?? 0,
      totalBycEarned: (json['totalBycEarned'] as num?)?.toDouble() ?? 0,
      referrals: refs
          .map((e) => ReferralItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class ReferralItem {
  final String id;
  final Map<String, dynamic>? referredUser;
  final String status;
  final int karmaAwarded;
  final double bycAwarded;
  final DateTime? signedUpAt;
  final DateTime? firstTradeAt;
  final DateTime? firstDonationAt;
  final DateTime? firstGiftAt;

  ReferralItem({
    required this.id,
    this.referredUser,
    required this.status,
    required this.karmaAwarded,
    required this.bycAwarded,
    this.signedUpAt,
    this.firstTradeAt,
    this.firstDonationAt,
    this.firstGiftAt,
  });

  factory ReferralItem.fromJson(Map<String, dynamic> json) {
    return ReferralItem(
      id: json['id'] as String? ?? '',
      referredUser: json['referredUser'] as Map<String, dynamic>?,
      status: json['status'] as String? ?? 'SIGNED_UP',
      karmaAwarded: (json['karmaAwarded'] as num?)?.toInt() ?? 0,
      bycAwarded: (json['bycAwarded'] as num?)?.toDouble() ?? 0,
      signedUpAt: _parseDate(json['signedUpAt']),
      firstTradeAt: _parseDate(json['firstTradeAt']),
      firstDonationAt: _parseDate(json['firstDonationAt']),
      firstGiftAt: _parseDate(json['firstGiftAt']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

class ReferralLookupResult {
  final String referrerId;
  final String displayName;

  ReferralLookupResult({required this.referrerId, required this.displayName});
}
