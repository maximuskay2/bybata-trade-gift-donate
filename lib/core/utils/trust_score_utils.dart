import '../../features/profile/models/user_profile.dart';

/// Parse trust score payload from `/v1/users/me` or `/v1/users/:id` profile.
TrustScore trustScoreFromApi(Map<String, dynamic>? profile) {
  final detail = profile?['trustScoreDetail'];
  if (detail is Map) {
    final d = Map<String, dynamic>.from(detail);
    final badges = (d['badges'] as List?)
            ?.whereType<Map>()
            .map((b) => TrustBadge.fromJson(Map<String, dynamic>.from(b)))
            .toList() ??
        <TrustBadge>[];
    return TrustScore(
      score: (d['score'] as num?)?.toDouble() ?? 0,
      level: (d['level'] as num?)?.toInt() ?? 1,
      badges: badges,
      lastUpdated: DateTime.tryParse(d['lastUpdated']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final score = (profile?['trustScore'] as num?)?.toDouble() ?? 0;
  return TrustScore(
    score: score,
    level: 1,
    badges: const [],
    lastUpdated: DateTime.now(),
  );
}

String formatTrustScoreDisplay(double score) {
  if (score <= 0) return '0';
  final rounded = (score * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) {
    return rounded.toInt().toString();
  }
  return rounded.toStringAsFixed(1);
}
