import 'package:flutter/material.dart';

import 'shadow_card.dart';

class CampaignProgressStat {
  final IconData icon;
  final String value;
  final String label;

  const CampaignProgressStat({
    required this.icon,
    required this.value,
    required this.label,
  });
}

/// Reusable donation progress block for campaign details.
class CampaignProgressCard extends StatelessWidget {
  final String formattedRaised;
  final String formattedGoal;
  final double progressPercentage;
  final Color progressColor;
  final List<CampaignProgressStat> stats;
  final Color? raisedColor;

  const CampaignProgressCard({
    super.key,
    required this.formattedRaised,
    required this.formattedGoal,
    required this.progressPercentage,
    required this.progressColor,
    required this.stats,
    this.raisedColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final raised = raisedColor ?? scheme.primary;
    final percent = (progressPercentage * 100).clamp(0, 100).toInt();

    return ShadowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedRaised,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: raised,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'of $formattedGoal',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progressPercentage.clamp(0.0, 1.0),
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: 24),
                _StatTile(stat: stats[i], scheme: scheme),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final CampaignProgressStat stat;
  final ColorScheme scheme;

  const _StatTile({required this.stat, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(stat.icon, size: 16, color: scheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stat.value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              stat.label,
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
