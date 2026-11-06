import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/karma_models.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Widget displaying recent KARMA activity/transactions
class RecentActivityWidget extends StatelessWidget {
  final List<KarmaTransaction> transactions;
  final void Function(KarmaTransaction)? onTransactionTap;

  const RecentActivityWidget({
    super.key,
    required this.transactions,
    this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
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
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No activity yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your KARMA activities will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
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
        children: List.generate(
          transactions.length,
          (index) => _buildTransactionItem(
            context,
            transactions[index],
            index,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    KarmaTransaction transaction,
    int index,
  ) {
    return GestureDetector(
      onTap: () => onTransactionTap?.call(transaction),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: index < transactions.length - 1
              ? Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade100,
                    width: 1,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            // Activity icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: transaction.activity.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                transaction.activity.icon,
                color: transaction.activity.color,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.activity.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimeAgo(transaction.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Points earned
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${transaction.pointsEarned}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ).animate().slideX(
        begin: 0.3,
        duration: Duration(milliseconds: 400 + (index * 100)),
        delay: Duration(milliseconds: index * 50),
        curve: Curves.easeOut,
      ).fadeIn(
        duration: Duration(milliseconds: 400 + (index * 100)),
        delay: Duration(milliseconds: index * 50),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    try {
      return timeago.format(dateTime, allowFromNow: true);
    } catch (e) {
      // Fallback if timeago fails
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    }
  }
}