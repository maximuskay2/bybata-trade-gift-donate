import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import '../models/wallet_models.dart';
import '../services/wallet_service.dart';

class RecentPromotionsList extends StatelessWidget {
  const RecentPromotionsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletService>(
      builder: (context, walletService, child) {
        final boosts = walletService.getTransactionHistory(
          limit: 10,
        ).where((t) => t.type == TransactionType.promotion || t.type == TransactionType.advert).toList();

        if (boosts.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: boosts
              .map((transaction) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildPromotionCard(context, transaction),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildPromotionCard(BuildContext context, WalletTransaction transaction) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = transaction.metadata['promotionTitle']?.toString() ??
        transaction.metadata['title']?.toString() ??
        transaction.description;
    return ShadowCard(
      shadowIntensity: ShadowIntensity.light,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                transaction.type == TransactionType.advert ? Icons.campaign : Icons.trending_up,
                color: scheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.type == TransactionType.advert ? 'Personal Ad' : 'Boosted Listing',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(transaction.timestamp),
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Text(
              '-${transaction.amount.toStringAsFixed(2)} BYC',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: scheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ShadowCard(
      shadowIntensity: ShadowIntensity.light,
      borderRadius: 12,
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        child: Column(
          children: [
            Icon(Icons.trending_up, size: 42, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No Boosts Yet',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            const SizedBox(height: 6),
            Text(
              'Your recent promotions will appear here',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
