import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';
import '../screens/wallet_pin_reset_otp_screen.dart';
import '../screens/wallet_pin_screen.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// How the user wants to reset their wallet PIN.
enum WalletPinResetChoice {
  currentPin,
  otp,
}

/// Bottom sheet for choosing a wallet PIN reset method (matches app modal style).
class WalletPinResetSheet extends StatelessWidget {
  const WalletPinResetSheet({super.key});

  static Future<WalletPinResetChoice?> show(BuildContext context) {
    return showModalBottomSheet<WalletPinResetChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WalletPinResetSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDarkMode ? 0.45 : 0.12),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reset wallet PIN',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.primaryText,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to set a new PIN.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: context.secondaryText,
                ),
              ),
              const SizedBox(height: 24),
              _ResetOptionTile(
                icon: Icons.pin_outlined,
                title: 'Reset with current PIN',
                subtitle: 'Enter your current PIN, then choose a new one.',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, WalletPinResetChoice.currentPin);
                },
              ),
              const SizedBox(height: 10),
              _ResetOptionTile(
                icon: Icons.email_outlined,
                title: 'Reset with email code',
                subtitle: 'We\'ll send a 6-digit code to your account email.',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, WalletPinResetChoice.otp);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.secondaryText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResetOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ResetOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.dividerColor),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: context.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.secondaryText,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.tertiaryText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navigates to the chosen PIN reset flow; returns `true` if PIN was reset.
class WalletPinResetFlow {
  WalletPinResetFlow._();

  static Future<bool> start(BuildContext context) async {
    final choice = await WalletPinResetSheet.show(context);
    if (choice == null || !context.mounted) return false;

    switch (choice) {
      case WalletPinResetChoice.currentPin:
        final result = await GuardedNavigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const WalletPinScreen(
              isSetting: true,
              isChangingPin: true,
            ),
          ),
        );
        return result == true;
      case WalletPinResetChoice.otp:
        final result = await GuardedNavigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const WalletPinResetOtpScreen(),
          ),
        );
        return result == true;
    }
  }
}
