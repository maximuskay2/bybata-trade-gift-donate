import 'package:flutter/material.dart';
import '../../features/karma/models/karma_models.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Maps API [TrustLevel] strings (NEWCOMER … LEGEND) to user-facing membership copy.
class KarmaMembershipInfo {
  final String tier;
  final String label;
  final bool isPremium;
  final String planName;
  final String? nextTierLabel;
  final int pointsToNextTier;
  final List<String> unlockedFeatures;

  const KarmaMembershipInfo({
    required this.tier,
    required this.label,
    required this.isPremium,
    required this.planName,
    this.nextTierLabel,
    this.pointsToNextTier = 0,
    this.unlockedFeatures = const [],
  });

  factory KarmaMembershipInfo.fromKarmaJson(Map<String, dynamic> json) {
    final points = (json['currentPoints'] as num?)?.toInt() ?? 0;
    final membership = json['membership'];
    if (membership is Map) {
      final m = Map<String, dynamic>.from(membership);
      return KarmaMembershipInfo(
        tier: m['tier']?.toString() ?? 'NEWCOMER',
        label: m['label']?.toString() ?? 'Newcomer',
        isPremium: m['isPremium'] == true,
        planName: m['planName']?.toString() ?? 'Newcomer',
        nextTierLabel: m['nextTierLabel']?.toString(),
        pointsToNextTier: (m['pointsToNextTier'] as num?)?.toInt() ?? 0,
        unlockedFeatures: unlockedFeaturesForPoints(points),
      );
    }

    final tier = json['trustLevel']?.toString() ?? 'NEWCOMER';
    return KarmaMembershipInfo.fromTier(tier, points);
  }

  factory KarmaMembershipInfo.fromTier(String tier, int points) {
    final label = membershipLabelForTier(tier);
    final premium = isPremiumTier(tier, points);
    final next = nextTierForPoints(points);
    return KarmaMembershipInfo(
      tier: tier,
      label: label,
      isPremium: premium,
      planName: premium ? 'Premium (KARMA)' : label,
      nextTierLabel: next.$1,
      pointsToNextTier: next.$2,
      unlockedFeatures: unlockedFeaturesForPoints(points),
    );
  }
}

String membershipLabelForTier(String tier) {
  switch (tier.toUpperCase()) {
    case 'LEGEND':
      return 'Legend';
    case 'DIAMOND':
      return 'Diamond';
    case 'PLATINUM':
      return 'Platinum';
    case 'GOLD':
      return 'Gold';
    case 'SILVER':
      return 'Silver';
    case 'BRONZE':
      return 'Bronze';
    default:
      return 'Newcomer';
  }
}

bool isPremiumTier(String tier, int points) {
  const premiumTiers = {'GOLD', 'PLATINUM', 'DIAMOND', 'LEGEND'};
  return premiumTiers.contains(tier.toUpperCase()) || points >= 5000;
}

(Color, IconData) tierStyle(String tier) {
  switch (tier.toUpperCase()) {
    case 'LEGEND':
      return (Colors.amber, Icons.military_tech_rounded);
    case 'DIAMOND':
      return (AppColors.primary, Icons.diamond_rounded);
    case 'PLATINUM':
      return (AppColors.primaryMuted, Icons.workspace_premium_rounded);
    case 'GOLD':
      return (Colors.orange, Icons.star_rounded);
    case 'SILVER':
      return (AppColors.primaryMuted, Icons.verified_rounded);
    case 'BRONZE':
      return (Colors.brown, Icons.shield_rounded);
    default:
      return (Colors.grey, Icons.person_outline_rounded);
  }
}

(String? nextLabel, int pointsNeeded) nextTierForPoints(int points) {
  const tiers = [
    ('BRONZE', 500),
    ('SILVER', 2000),
    ('GOLD', 5000),
    ('PLATINUM', 10000),
    ('DIAMOND', 25000),
    ('LEGEND', 50000),
  ];
  for (final t in tiers) {
    if (points < t.$2) {
      return (membershipLabelForTier(t.$1), t.$2 - points);
    }
  }
  return (null, 0);
}

/// Maps API karma tiers (NEWCOMER … LEGEND) to app [TrustLevel].
TrustLevel mapApiTrustLevelToLocal(String apiTier, {int points = 0}) {
  switch (apiTier.toUpperCase()) {
    case 'LEGEND':
    case 'DIAMOND':
      return TrustLevel.ambassador;
    case 'PLATINUM':
    case 'GOLD':
      return TrustLevel.premium;
    case 'SILVER':
      return TrustLevel.trusted;
    case 'BRONZE':
      return TrustLevel.basic;
    default:
      return points >= 500 ? TrustLevel.basic : TrustLevel.unverified;
  }
}

/// KARMA tier ladder (lowest → highest).
const List<({String id, String label, int minPoints})> karmaTierLadder = [
  (id: 'NEWCOMER', label: 'Newcomer', minPoints: 0),
  (id: 'BRONZE', label: 'Bronze', minPoints: 500),
  (id: 'SILVER', label: 'Silver', minPoints: 2000),
  (id: 'GOLD', label: 'Gold', minPoints: 5000),
  (id: 'PLATINUM', label: 'Platinum', minPoints: 10000),
  (id: 'DIAMOND', label: 'Diamond', minPoints: 25000),
  (id: 'LEGEND', label: 'Legend', minPoints: 50000),
];

int karmaTierIndex(String tierId) {
  final i = karmaTierLadder.indexWhere(
    (t) => t.id == tierId.toUpperCase(),
  );
  return i < 0 ? 0 : i;
}

int karmaTierIndexForPoints(int points) {
  var idx = 0;
  for (var i = 0; i < karmaTierLadder.length; i++) {
    if (points >= karmaTierLadder[i].minPoints) idx = i;
  }
  return idx;
}

double karmaTierProgress(int points) {
  final idx = karmaTierIndexForPoints(points);
  if (idx >= karmaTierLadder.length - 1) return 1;
  final current = karmaTierLadder[idx].minPoints;
  final next = karmaTierLadder[idx + 1].minPoints;
  if (next <= current) return 1;
  return ((points - current) / (next - current)).clamp(0.0, 1.0);
}

List<String> unlockedFeaturesForPoints(int points) {
  const gates = [
    (100, 'Premium Trade Filters'),
    (150, 'Gift Scheduling'),
    (200, 'Exclusive Communities'),
    (250, 'Higher Trading Limits'),
    (600, 'Priority Support'),
  ];
  return [
    for (final g in gates)
      if (points >= g.$1) g.$2,
  ];
}
