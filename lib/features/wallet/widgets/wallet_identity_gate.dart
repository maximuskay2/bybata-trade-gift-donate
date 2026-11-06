import 'package:flutter/material.dart';

import '../../profile/screens/verification_screen.dart';
import '../../profile/services/verification_check_service.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Blocks outbound BYC flows until identity verification (KYC) is complete.
class WalletIdentityGate extends StatelessWidget {
  final String title;
  final String message;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback onVerificationChanged;

  const WalletIdentityGate({
    super.key,
    required this.title,
    required this.message,
    required this.primaryColor,
    required this.isDark,
    required this.onVerificationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified_user_rounded, size: 64, color: primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final profile = await VerificationCheckService.fetchCurrentProfile();
                if (!context.mounted || profile == null) return;
                // Already verified — refresh parent gate instead of opening KYC flow.
                if (profile.isVerified) {
                  onVerificationChanged();
                  return;
                }
                await GuardedNavigator.push(context,
                  MaterialPageRoute(
                    builder: (_) => VerificationScreen(userProfile: profile),
                  ),
                );
                if (context.mounted) onVerificationChanged();
              },
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Go to Verification'),
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
