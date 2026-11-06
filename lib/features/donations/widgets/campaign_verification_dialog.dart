import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum CampaignVerificationAction { dismiss, openDonationsHub }

/// Shown after a new campaign is submitted — explains admin review before going live.
class CampaignVerificationDialog extends StatelessWidget {
  final String campaignTitle;

  const CampaignVerificationDialog({
    super.key,
    required this.campaignTitle,
  });

  static Future<CampaignVerificationAction> show(
    BuildContext context, {
    required String campaignTitle,
  }) {
    return showDialog<CampaignVerificationAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CampaignVerificationDialog(campaignTitle: campaignTitle),
    ).then((value) => value ?? CampaignVerificationAction.dismiss);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.donationColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_outlined,
              color: AppTheme.donationColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Campaign submitted',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campaignTitle,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your campaign is under verification. Our team will review it and make it live soon — you\'ll be notified when it\'s published.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: scheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            CampaignVerificationAction.dismiss,
          ),
          child: const Text('Got it'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            CampaignVerificationAction.openDonationsHub,
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.donationColor,
          ),
          child: const Text('Go to Donations'),
        ),
      ],
    );
  }
}
