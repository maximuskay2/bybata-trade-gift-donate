import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Quick action buttons for KARMA features
class KarmaQuickActions extends StatelessWidget {
  final VoidCallback? onEarnKarma;
  final VoidCallback? onViewLeaderboard;
  final VoidCallback? onViewHistory;
  final VoidCallback? onViewAchievements;

  const KarmaQuickActions({
    super.key,
    this.onEarnKarma,
    this.onViewLeaderboard,
    this.onViewHistory,
    this.onViewAchievements,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  'Earn KARMA',
                  Icons.add_circle_outline,
                  Colors.green,
                  onEarnKarma,
                ).animate().slideX(
                  begin: -0.3,
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  'Leaderboard',
                  Icons.leaderboard,
                  Colors.orange,
                  onViewLeaderboard,
                ).animate().slideX(
                  begin: 0.3,
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  'History',
                  Icons.history,
                  AppColors.primary,
                  onViewHistory,
                ).animate().slideX(
                  begin: -0.3,
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  'Achievements',
                  Icons.emoji_events,
                  Colors.purple,
                  onViewAchievements,
                ).animate().slideX(
                  begin: 0.3,
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}