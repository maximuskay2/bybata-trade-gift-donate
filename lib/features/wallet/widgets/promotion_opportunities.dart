import 'package:flutter/material.dart';
import '../../../core/widgets/bybata_glass_container.dart';

class PromotionOpportunities extends StatelessWidget {
  final VoidCallback onCreatePromotion;
  const PromotionOpportunities({super.key, required this.onCreatePromotion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, size: 18),
              const SizedBox(width: 8),
              Text('Promotion Opportunities', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              _buildCreateButton(context),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Boost listings for more visibility in feeds, or create a custom ad with your own link and creative.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onCreatePromotion,
      child: ByBataGlassContainer(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.primary.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: scheme.onPrimary),
              const SizedBox(width: 6),
              Text(
                'Create',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
