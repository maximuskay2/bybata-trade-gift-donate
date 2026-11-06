import 'package:flutter/material.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Trust level indicator component
class TrustIndicator extends StatelessWidget {
  final double trustLevel; // 0.0 to 1.0
  final TrustIndicatorSize size;
  final bool showLabel;
  final bool showPercentage;

  const TrustIndicator({
    Key? key,
    required this.trustLevel,
    this.size = TrustIndicatorSize.medium,
    this.showLabel = true,
    this.showPercentage = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final trustInfo = _getTrustLevelInfo(trustLevel);
    final percentage = (trustLevel * 100).round();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(_getIconPadding()),
          decoration: BoxDecoration(
            color: trustInfo.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            trustInfo.icon,
            color: trustInfo.color,
            size: _getIconSize(),
          ),
        ),
        if (showLabel || showPercentage) SizedBox(width: _getSpacing()),
        if (showLabel || showPercentage)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLabel)
                Text(
                  trustInfo.label,
                  style: TextStyle(
                    fontSize: _getLabelFontSize(),
                    fontWeight: FontWeight.w600,
                    color: trustInfo.color,
                  ),
                ),
              if (showPercentage)
                Text(
                  '$percentage% Trust',
                  style: TextStyle(
                    fontSize: _getPercentageFontSize(),
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  TrustLevelInfo _getTrustLevelInfo(double trustLevel) {
    if (trustLevel >= 0.9) {
      return TrustLevelInfo(
        label: 'Highly Trusted',
        icon: Icons.verified,
        color: const Color(0xFF4CAF50), // Green
      );
    } else if (trustLevel >= 0.75) {
      return TrustLevelInfo(
        label: 'Trusted',
        icon: Icons.check_circle,
        color: AppColors.primary, // Blue
      );
    } else if (trustLevel >= 0.5) {
      return TrustLevelInfo(
        label: 'Reliable',
        icon: Icons.thumb_up,
        color: AppColors.primaryLight, // Cyan
      );
    } else if (trustLevel >= 0.3) {
      return TrustLevelInfo(
        label: 'Building Trust',
        icon: Icons.trending_up,
        color: const Color(0xFFFF9800), // Orange
      );
    } else {
      return TrustLevelInfo(
        label: 'New User',
        icon: Icons.help_outline,
        color: const Color(0xFF9E9E9E), // Grey
      );
    }
  }

  double _getIconSize() {
    switch (size) {
      case TrustIndicatorSize.small:
        return 16;
      case TrustIndicatorSize.medium:
        return 20;
      case TrustIndicatorSize.large:
        return 24;
    }
  }

  double _getIconPadding() {
    switch (size) {
      case TrustIndicatorSize.small:
        return 4;
      case TrustIndicatorSize.medium:
        return 6;
      case TrustIndicatorSize.large:
        return 8;
    }
  }

  double _getSpacing() {
    switch (size) {
      case TrustIndicatorSize.small:
        return 6;
      case TrustIndicatorSize.medium:
        return 8;
      case TrustIndicatorSize.large:
        return 10;
    }
  }

  double _getLabelFontSize() {
    switch (size) {
      case TrustIndicatorSize.small:
        return 12;
      case TrustIndicatorSize.medium:
        return 14;
      case TrustIndicatorSize.large:
        return 16;
    }
  }

  double _getPercentageFontSize() {
    switch (size) {
      case TrustIndicatorSize.small:
        return 10;
      case TrustIndicatorSize.medium:
        return 12;
      case TrustIndicatorSize.large:
        return 14;
    }
  }
}

/// Trust indicator with progress bar
class TrustIndicatorWithProgress extends StatelessWidget {
  final double trustLevel; // 0.0 to 1.0
  final bool showPercentage;
  final double width;

  const TrustIndicatorWithProgress({
    Key? key,
    required this.trustLevel,
    this.showPercentage = true,
    this.width = 150,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final trustInfo = _getTrustLevelInfo(trustLevel);
    final percentage = (trustLevel * 100).round();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              trustInfo.icon,
              color: trustInfo.color,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              trustInfo.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: trustInfo.color,
              ),
            ),
            if (showPercentage) ...[
              const Spacer(),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            widthFactor: trustLevel,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: trustInfo.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  TrustLevelInfo _getTrustLevelInfo(double trustLevel) {
    if (trustLevel >= 0.9) {
      return TrustLevelInfo(
        label: 'Highly Trusted',
        icon: Icons.verified,
        color: const Color(0xFF4CAF50),
      );
    } else if (trustLevel >= 0.75) {
      return TrustLevelInfo(
        label: 'Trusted',
        icon: Icons.check_circle,
        color: AppColors.primary,
      );
    } else if (trustLevel >= 0.5) {
      return TrustLevelInfo(
        label: 'Reliable',
        icon: Icons.thumb_up,
        color: AppColors.primaryLight,
      );
    } else if (trustLevel >= 0.3) {
      return TrustLevelInfo(
        label: 'Building Trust',
        icon: Icons.trending_up,
        color: const Color(0xFFFF9800),
      );
    } else {
      return TrustLevelInfo(
        label: 'New User',
        icon: Icons.help_outline,
        color: const Color(0xFF9E9E9E),
      );
    }
  }
}

/// Compact trust indicator for lists
class TrustIndicatorCompact extends StatelessWidget {
  final double trustLevel;
  
  const TrustIndicatorCompact({
    Key? key,
    required this.trustLevel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TrustIndicator(
      trustLevel: trustLevel,
      size: TrustIndicatorSize.small,
      showLabel: false,
      showPercentage: false,
    );
  }
}

/// Trust level verification badge
class TrustVerificationBadge extends StatelessWidget {
  final bool isVerified;
  final String? verificationLevel;

  const TrustVerificationBadge({
    Key? key,
    required this.isVerified,
    this.verificationLevel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    final level = verificationLevel ?? 'Verified';
    Color badgeColor;
    IconData icon;

    switch (level.toLowerCase()) {
      case 'gold':
        badgeColor = const Color(0xFFFFD700);
        icon = Icons.military_tech;
        break;
      case 'silver':
        badgeColor = const Color(0xFFC0C0C0);
        icon = Icons.verified_user;
        break;
      case 'bronze':
        badgeColor = const Color(0xFFCD7F32);
        icon = Icons.verified;
        break;
      default:
        badgeColor = const Color(0xFF4CAF50);
        icon = Icons.verified;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            level,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Trust indicator size options
enum TrustIndicatorSize {
  small,
  medium,
  large,
}

/// Data class for trust level information
class TrustLevelInfo {
  final String label;
  final IconData icon;
  final Color color;

  TrustLevelInfo({
    required this.label,
    required this.icon,
    required this.color,
  });
}