import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Branded modal shown when a guest tries a signed-in-only action.
class SignInRequiredDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? highlight;

  const SignInRequiredDialog({
    super.key,
    this.title = 'Sign in to continue',
    this.message =
        'Create a free account or sign in to trade, donate, message members, and unlock your wallet.',
    this.highlight,
  });

  /// Presents the dialog and returns when it is dismissed.
  static Future<void> show(
    BuildContext context, {
    String? title,
    String? message,
    String? highlight,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss sign in prompt',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, __) => SignInRequiredDialog(
        title: title ?? 'Sign in to continue',
        message: message ??
            'Create a free account or sign in to trade, donate, message members, and unlock your wallet.',
        highlight: highlight,
      ),
      transitionBuilder: (ctx, animation, _, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  void _close(BuildContext context) => Navigator.of(context).pop();

  void _goToLogin(BuildContext context) {
    _close(context);
    GuardedNavigator.pushNamed(context, AppConstants.loginRoute);
  }

  void _goToRegister(BuildContext context) {
    _close(context);
    GuardedNavigator.pushNamed(context, AppConstants.registerRoute);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryColor;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1524).withValues(alpha: 0.96)
                      : Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : primary.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: isDark ? 0.25 : 0.18),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DialogHeader(
                      primary: primary,
                      isDark: isDark,
                      onClose: () => _close(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: scheme.onSurface,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: scheme.onSurface.withValues(alpha: 0.68),
                            ),
                          ),
                          if (highlight != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: primary.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 18,
                                    color: primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      highlight!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          _PrimaryActionButton(
                            label: 'Sign In',
                            onPressed: () => _goToLogin(context),
                          ),
                          const SizedBox(height: 10),
                          _SecondaryActionButton(
                            label: 'Create free account',
                            onPressed: () => _goToRegister(context),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => _close(context),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  scheme.onSurface.withValues(alpha: 0.55),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text(
                              'Continue browsing',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final Color primary;
  final bool isDark;
  final VoidCallback onClose;

  const _DialogHeader({
    required this.primary,
    required this.isDark,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 112,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      primary.withValues(alpha: 0.35),
                      const Color(0xFF2D2240),
                    ]
                  : [
                      primary.withValues(alpha: 0.16),
                      AppColors.primarySurface,
                    ],
            ),
          ),
          child: Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary,
                    primary.withValues(alpha: 0.75),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white)
                      .withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [primary, primary.withValues(alpha: 0.82)],
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryActionButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = AppTheme.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.18)
              : primary.withValues(alpha: 0.28),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        foregroundColor: scheme.onSurface,
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}
