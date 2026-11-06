import 'package:flutter/material.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Badge component that displays user KARMA level with appropriate styling
class KarmaLevelBadge extends StatelessWidget {
  final int karmaPoints;
  final String? level;
  final KarmaBadgeSize size;
  final bool showPoints;
  final bool showLabel;

  const KarmaLevelBadge({
    Key? key,
    required this.karmaPoints,
    this.level,
    this.size = KarmaBadgeSize.medium,
    this.showPoints = true,
    this.showLabel = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final levelInfo = _getKarmaLevelInfo(karmaPoints);
    final displayLevel = level ?? levelInfo.level;
    
    return Container(
      padding: _getPadding(),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: levelInfo.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_getBorderRadius()),
        boxShadow: [
          BoxShadow(
color: levelInfo.gradientColors.first.withValues(alpha: 0.3),
            blurRadius: _getBlurRadius(),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            levelInfo.icon,
            color: Colors.white,
            size: _getIconSize(),
          ),
          if (showLabel || showPoints) SizedBox(width: _getSpacing()),
          if (showLabel || showPoints)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showLabel)
                  Text(
                    displayLevel,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _getLabelFontSize(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (showPoints)
                  Text(
                    '$karmaPoints KARMA',
                    style: TextStyle(
color: Colors.white.withValues(alpha: 0.9),
                      fontSize: _getPointsFontSize(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  KarmaLevelInfo _getKarmaLevelInfo(int points) {
    if (points >= 10000) {
      return KarmaLevelInfo(
        level: 'Master',
        icon: Icons.emoji_events,
        gradientColors: [const Color(0xFFFFD700), const Color(0xFFFFA500)], // Gold
      );
    } else if (points >= 5000) {
      return KarmaLevelInfo(
        level: 'Expert',
        icon: Icons.star,
        gradientColors: [const Color(0xFF9C27B0), const Color(0xFF673AB7)], // Purple
      );
    } else if (points >= 2500) {
      return KarmaLevelInfo(
        level: 'Advanced',
        icon: Icons.trending_up,
        gradientColors: [AppColors.primary, AppColors.primary], // Blue
      );
    } else if (points >= 1000) {
      return KarmaLevelInfo(
        level: 'Intermediate',
        icon: Icons.favorite,
        gradientColors: [const Color(0xFF4CAF50), const Color(0xFF388E3C)], // Green
      );
    } else if (points >= 500) {
      return KarmaLevelInfo(
        level: 'Rising',
        icon: Icons.arrow_upward,
        gradientColors: [const Color(0xFFFF9800), const Color(0xFFF57C00)], // Orange
      );
    } else if (points >= 100) {
      return KarmaLevelInfo(
        level: 'Novice',
        icon: Icons.child_friendly,
        gradientColors: [AppColors.primaryLight, AppColors.primaryDark], // Cyan
      );
    } else {
      return KarmaLevelInfo(
        level: 'Beginner',
        icon: Icons.eco,
        gradientColors: [AppColors.primaryMuted, AppColors.primaryDeep], // Blue Grey
      );
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case KarmaBadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case KarmaBadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case KarmaBadgeSize.large:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    }
  }

  double _getBorderRadius() {
    switch (size) {
      case KarmaBadgeSize.small:
        return 12;
      case KarmaBadgeSize.medium:
        return 16;
      case KarmaBadgeSize.large:
        return 20;
    }
  }

  double _getBlurRadius() {
    switch (size) {
      case KarmaBadgeSize.small:
        return 4;
      case KarmaBadgeSize.medium:
        return 6;
      case KarmaBadgeSize.large:
        return 8;
    }
  }

  double _getIconSize() {
    switch (size) {
      case KarmaBadgeSize.small:
        return 16;
      case KarmaBadgeSize.medium:
        return 20;
      case KarmaBadgeSize.large:
        return 24;
    }
  }

  double _getSpacing() {
    switch (size) {
      case KarmaBadgeSize.small:
        return 4;
      case KarmaBadgeSize.medium:
        return 6;
      case KarmaBadgeSize.large:
        return 8;
    }
  }

  double _getLabelFontSize() {
    switch (size) {
      case KarmaBadgeSize.small:
        return 12;
      case KarmaBadgeSize.medium:
        return 14;
      case KarmaBadgeSize.large:
        return 16;
    }
  }

  double _getPointsFontSize() {
    switch (size) {
      case KarmaBadgeSize.small:
        return 10;
      case KarmaBadgeSize.medium:
        return 12;
      case KarmaBadgeSize.large:
        return 14;
    }
  }
}

/// Badge size options
enum KarmaBadgeSize {
  small,
  medium,
  large,
}

/// Data class for karma level information
class KarmaLevelInfo {
  final String level;
  final IconData icon;
  final List<Color> gradientColors;

  KarmaLevelInfo({
    required this.level,
    required this.icon,
    required this.gradientColors,
  });
}

/// Compact version of karma badge for lists
class KarmaLevelBadgeCompact extends StatelessWidget {
  final int karmaPoints;
  
  const KarmaLevelBadgeCompact({
    Key? key,
    required this.karmaPoints,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return KarmaLevelBadge(
      karmaPoints: karmaPoints,
      size: KarmaBadgeSize.small,
      showPoints: false,
      showLabel: false,
    );
  }
}

/// Icon-only karma level indicator
class KarmaLevelIcon extends StatelessWidget {
  final int karmaPoints;
  final double? size;
  
  const KarmaLevelIcon({
    Key? key,
    required this.karmaPoints,
    this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final levelInfo = _getKarmaLevelInfo(karmaPoints);
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: levelInfo.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        levelInfo.icon,
        color: Colors.white,
        size: size ?? 16,
      ),
    );
  }

  KarmaLevelInfo _getKarmaLevelInfo(int points) {
    if (points >= 10000) {
      return KarmaLevelInfo(
        level: 'Master',
        icon: Icons.emoji_events,
        gradientColors: [const Color(0xFFFFD700), const Color(0xFFFFA500)],
      );
    } else if (points >= 5000) {
      return KarmaLevelInfo(
        level: 'Expert',
        icon: Icons.star,
        gradientColors: [const Color(0xFF9C27B0), const Color(0xFF673AB7)],
      );
    } else if (points >= 2500) {
      return KarmaLevelInfo(
        level: 'Advanced',
        icon: Icons.trending_up,
        gradientColors: [AppColors.primary, AppColors.primary],
      );
    } else if (points >= 1000) {
      return KarmaLevelInfo(
        level: 'Intermediate',
        icon: Icons.favorite,
        gradientColors: [const Color(0xFF4CAF50), const Color(0xFF388E3C)],
      );
    } else if (points >= 500) {
      return KarmaLevelInfo(
        level: 'Rising',
        icon: Icons.arrow_upward,
        gradientColors: [const Color(0xFFFF9800), const Color(0xFFF57C00)],
      );
    } else if (points >= 100) {
      return KarmaLevelInfo(
        level: 'Novice',
        icon: Icons.child_friendly,
        gradientColors: [AppColors.primaryLight, AppColors.primaryDark],
      );
    } else {
      return KarmaLevelInfo(
        level: 'Beginner',
        icon: Icons.eco,
        gradientColors: [AppColors.primaryMuted, AppColors.primaryDeep],
      );
    }
  }
}