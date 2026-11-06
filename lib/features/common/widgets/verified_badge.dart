import 'package:flutter/material.dart';

/// Green tick badge for KYC-verified users.
/// Use next to usernames in profiles, lists, community posts, and trading interfaces.
class VerifiedBadge extends StatelessWidget {
  final bool isVerified;
  final double size;
  final bool showTooltip;

  const VerifiedBadge({
    super.key,
    required this.isVerified,
    this.size = 18,
    this.showTooltip = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        Icons.check,
        size: size * 0.6,
        color: Colors.white,
      ),
    );

    if (showTooltip) {
      return Tooltip(
        message: 'Verified identity',
        child: badge,
      );
    }
    return badge;
  }
}

/// Inline verified badge to place next to a name in a Row.
/// Example: Row(children: [Text(name), VerifiedBadgeInline(isVerified: true)])
class VerifiedBadgeInline extends StatelessWidget {
  final bool isVerified;
  final double size;

  const VerifiedBadgeInline({
    super.key,
    required this.isVerified,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: VerifiedBadge(isVerified: true, size: size, showTooltip: true),
    );
  }
}
