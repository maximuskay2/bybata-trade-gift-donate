import 'package:flutter/material.dart';
import '../models/karma_models.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Widget displaying KARMA statistics and analytics
class KarmaStatsWidget extends StatelessWidget {
  final UserKarma userKarma;

  const KarmaStatsWidget({
    super.key,
    required this.userKarma,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KARMA Statistics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Global Rank',
                  '#${userKarma.stats.globalRank}',
                  Icons.public,
                  AppColors.primary,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'This Week',
                  '${userKarma.stats.thisWeekPoints}',
                      Icons.calendar_today,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Achievements',
                  '${userKarma.achievements.length}',
                  Icons.emoji_events,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}