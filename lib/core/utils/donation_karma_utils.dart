import '../karma/karma_points_config.dart';

/// Donation karma — percent from admin config when available.
int calculateDonationKarmaReward(
  double amount, {
  double? percent,
}) {
  final p = percent ?? KarmaPointsConfigCache.instance.current.donationKarmaPercent;
  if (amount <= 0 || p <= 0) return 0;
  return (amount * p / 100).floor();
}
