import 'package:flutter/material.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';
import '../navigation/wallet_navigator.dart';
import '../screens/enhanced_fund_wallet_screen.dart';
import 'package:bybata/core/theme/app_theme.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class QuickActionButtons extends StatelessWidget {
  const QuickActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            'Fund',
            Icons.add_circle_outline,
            AppColors.primary,
            () => GuardedNavigator.push(context, 
              MaterialPageRoute(
                builder: (context) => const EnhancedFundWalletScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            context,
            'Send',
            Icons.send_outlined,
            Colors.red,
            () => WalletNavigator.toSendBYC(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            context,
            'Receive',
            Icons.call_received_outlined,
            Colors.green,
            () => WalletNavigator.toReceiveBYC(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            context,
            'History',
            Icons.history_outlined,
            Colors.orange,
            () => WalletNavigator.toTransactionHistory(context),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ShadowCard(
      shadowIntensity: ShadowIntensity.light,
      onTap: onTap,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}