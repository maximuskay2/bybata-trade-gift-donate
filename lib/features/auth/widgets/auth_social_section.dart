import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_extensions.dart';

/// Google + Apple sign-in icon buttons used on login and sign-up.
class AuthSocialSection extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;
  final bool showTopDivider;
  final String dividerLabel;

  const AuthSocialSection({
    super.key,
    required this.isLoading,
    required this.onGoogle,
    required this.onApple,
    this.showTopDivider = false,
    this.dividerLabel = 'or continue with email',
  });

  static bool get showAppleButton {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static bool get showGoogleButton => !kIsWeb;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    if (showGoogleButton) {
      buttons.add(
        _SocialIconButton(
          semanticLabel: 'Sign in with Google',
          icon: Icons.g_mobiledata_rounded,
          iconSize: 30,
          onPressed: isLoading ? null : onGoogle,
        ),
      );
    }

    if (showAppleButton) {
      buttons.add(
        _SocialIconButton(
          semanticLabel: 'Sign in with Apple',
          icon: Icons.apple_rounded,
          iconSize: 26,
          onPressed: isLoading ? null : onApple,
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];

    if (showTopDivider) {
      children.add(AuthOrDivider(label: dividerLabel));
      children.add(const SizedBox(height: 20));
    }

    children.add(
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            buttons[i],
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  final String label;

  const AuthOrDivider({super.key, this.label = 'or'});

  @override
  Widget build(BuildContext context) {
    final line = context.dividerColor;
    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: context.secondaryText,
    );

    return Row(
      children: [
        Expanded(child: Divider(color: line, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(label, style: textStyle),
        ),
        Expanded(child: Divider(color: line, height: 1)),
      ],
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final String semanticLabel;
  final IconData icon;
  final double iconSize;
  final VoidCallback? onPressed;

  const _SocialIconButton({
    required this.semanticLabel,
    required this.icon,
    required this.iconSize,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: Material(
          color: context.cardSurface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.dividerColor),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: iconSize, color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact header used on auth screens.
class AuthScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            'assets/animations/logo_small.png',
            width: 44,
            height: 44,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.rocket_launch_rounded, size: 44, color: primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: context.primaryText,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.35,
            color: context.secondaryText,
          ),
        ),
      ],
    );
  }
}
