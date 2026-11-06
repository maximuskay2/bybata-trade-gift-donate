import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import '../models/wallet_models.dart';
import '../services/wallet_service.dart';

class RecentTransactionsList extends StatelessWidget {
  /// Max number of transactions to show. If null, shows all from recentTransactions (10).
  final int? limit;
  /// Called when user taps "View All". If null, no button is shown.
  final VoidCallback? onViewAll;

  const RecentTransactionsList({
    super.key,
    this.limit,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletService>(
      builder: (context, walletService, child) {
        var transactions = walletService.recentTransactions;
        if (limit != null && transactions.length > limit!) {
          transactions = transactions.take(limit!).toList();
        }

        if (transactions.isEmpty) {
          return _buildEmptyState();
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...transactions.map((transaction) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildTransactionCard(context, transaction),
                ),
              ),
              if (onViewAll != null && transactions.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildViewAllButton(context),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildViewAllButton(BuildContext context) {
    return TextButton.icon(
      onPressed: onViewAll,
      icon: const Icon(Icons.history, size: 18),
      label: const Text('View Transaction History'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, WalletTransaction transaction) {
    return ShadowCard(
      shadowIntensity: ShadowIntensity.light,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Transaction Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: transaction.statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                transaction.typeIcon,
                color: transaction.statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            
            // Transaction Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _formatTransactionTime(transaction.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (transaction.recipientName != null || transaction.senderName != null) ...[
                        Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          transaction.recipientName ?? transaction.senderName ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (transaction.fee > 0)
                    Text(
                      'Fee: ${transaction.fee.toStringAsFixed(2)} BYC',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            
            // Amount and Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${transaction.isOutgoing ? '-' : '+'}${transaction.amount.toStringAsFixed(2)} BYC',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: transaction.isOutgoing ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: transaction.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(transaction.status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: transaction.statusColor,
                    ),
                  ),
                ),
              ],
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
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Transactions Yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your recent transactions will appear here',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTransactionTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String _getStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.processing:
        return 'Processing';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
      case TransactionStatus.refunded:
        return 'Refunded';
    }
  }
}