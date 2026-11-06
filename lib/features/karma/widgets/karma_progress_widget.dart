import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/karma_models.dart';

/// Widget displaying user's KARMA level progress
class KarmaProgressWidget extends StatelessWidget {
  final UserKarma userKarma;
  final AnimationController? animationController;

  const KarmaProgressWidget({
    super.key,
    required this.userKarma,
    this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Current and next level display
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLevelIndicator(
              context,
              userKarma.level,
              'Current',
              isActive: true,
            ),
            if (userKarma.level != KarmaLevel.legend)
              _buildLevelIndicator(
                context,
                _getNextLevel(userKarma.level),
                'Next',
                isActive: false,
              ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Progress bar
        _buildProgressBar(context),
        
        const SizedBox(height: 12),
        
        // Progress text
        _buildProgressText(context),
      ],
    );
  }

  Widget _buildLevelIndicator(
    BuildContext context,
    KarmaLevel level,
    String label,
    {required bool isActive}
  ) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isActive ? level.color.withValues(alpha: 0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? level.color : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              level.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ).animate().scale(
          duration: const Duration(milliseconds: 600),
          delay: Duration(milliseconds: isActive ? 0 : 300),
          curve: Curves.elasticOut,
        ),
        const SizedBox(height: 8),
        Text(
          level.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isActive ? level.color : Colors.grey.shade600,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final progress = userKarma.progressToNextLevel;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${userKarma.totalPoints}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: userKarma.level.color,
              ),
            ),
            if (userKarma.level != KarmaLevel.legend)
              Text(
                '${_getNextLevel(userKarma.level).minPoints}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: animationController != null 
                ? (animationController!.value * progress)
                : progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                userKarma.level.color,
              ),
            ),
          ),
        ).animate().slideX(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
        ),
      ],
    );
  }

  Widget _buildProgressText(BuildContext context) {
    if (userKarma.level == KarmaLevel.legend) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: userKarma.level.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events,
              color: userKarma.level.color,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Maximum Level Reached!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: userKarma.level.color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final pointsToNext = userKarma.pointsToNextLevel;
    final progressPercentage = (userKarma.progressToNextLevel * 100).toInt();

    return Column(
      children: [
        Text(
          '$pointsToNext points to next level',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$progressPercentage% complete',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  KarmaLevel _getNextLevel(KarmaLevel currentLevel) {
    final currentIndex = KarmaLevel.values.indexOf(currentLevel);
    if (currentIndex < KarmaLevel.values.length - 1) {
      return KarmaLevel.values[currentIndex + 1];
    }
    return currentLevel; // Already at max level
  }
}