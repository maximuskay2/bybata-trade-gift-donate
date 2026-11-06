import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/donation_karma_utils.dart';

/// Shown after a successful campaign donation (in-app or returning from web).
class DonationSuccessDialog extends StatelessWidget {
  final double amountByc;
  final int karmaEarned;
  final String? campaignTitle;

  const DonationSuccessDialog({
    super.key,
    required this.amountByc,
    required this.karmaEarned,
    this.campaignTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required double amountByc,
    int? karmaEarned,
    String? campaignTitle,
  }) {
    final karma = karmaEarned ??
        (amountByc > 0 ? calculateDonationKarmaReward(amountByc) : 0);
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DonationSuccessDialog(
        amountByc: amountByc,
        karmaEarned: karma,
        campaignTitle: campaignTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = campaignTitle?.trim();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.donationColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.volunteer_activism_rounded,
                size: 36,
                color: AppTheme.donationColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thank you!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.donationColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title != null && title.isNotEmpty
                  ? 'Your support of ${amountByc.toStringAsFixed(0)} BYC was sent to “$title”.'
                  : 'Your support of ${amountByc.toStringAsFixed(0)} BYC was sent successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Colors.grey.shade700,
              ),
            ),
            if (karmaEarned > 0) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.karmaColor.withValues(alpha: 0.15),
                      AppTheme.karmaColor.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.karmaColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stars_rounded, color: AppTheme.karmaColor),
                    const SizedBox(width: 8),
                    Text(
                      '+$karmaEarned KARMA earned',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.karmaColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.donationColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
