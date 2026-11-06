import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// BYC (Bybata Coin) amount display component
class BYCAmountDisplay extends StatelessWidget {
  final double amount;
  final BYCDisplaySize size;
  final bool showIcon;
  final bool showCurrency;
  final Color? textColor;
  final Color? iconColor;
  final bool isPositive;
  final String? prefix;
  final TextAlign? textAlign;

  const BYCAmountDisplay({
    Key? key,
    required this.amount,
    this.size = BYCDisplaySize.medium,
    this.showIcon = true,
    this.showCurrency = true,
    this.textColor,
    this.iconColor,
    this.isPositive = true,
    this.prefix,
    this.textAlign,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formattedAmount = _formatAmount(amount);
    final displayColor = textColor ?? _getDefaultColor();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          _buildCoinIcon(),
          SizedBox(width: _getSpacing()),
        ],
        if (prefix != null) ...[
          Text(
            prefix!,
            style: TextStyle(
              fontSize: _getFontSize(),
              fontWeight: FontWeight.w500,
              color: displayColor,
            ),
          ),
          SizedBox(width: _getSpacing() / 2),
        ],
        Text(
          formattedAmount,
          style: TextStyle(
            fontSize: _getFontSize(),
            fontWeight: _getFontWeight(),
            color: displayColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          textAlign: textAlign,
        ),
        if (showCurrency) ...[
          SizedBox(width: _getSpacing() / 2),
          Text(
            'BYC',
            style: TextStyle(
              fontSize: _getFontSize() * 0.8,
              fontWeight: FontWeight.w600,
              color: displayColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCoinIcon() {
    return Container(
      width: _getIconSize(),
      height: _getIconSize(),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)], // Gold gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.monetization_on,
        color: Colors.white,
        size: _getIconSize() * 0.7,
      ),
    );
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat.currency(
      symbol: '',
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    );
    return formatter.format(amount.abs()).trim();
  }

  Color _getDefaultColor() {
    if (amount == 0) return Colors.grey.shade600;
    return isPositive ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
  }

  double _getFontSize() {
    switch (size) {
      case BYCDisplaySize.small:
        return 12;
      case BYCDisplaySize.medium:
        return 16;
      case BYCDisplaySize.large:
        return 20;
      case BYCDisplaySize.extraLarge:
        return 24;
    }
  }

  FontWeight _getFontWeight() {
    switch (size) {
      case BYCDisplaySize.small:
        return FontWeight.w500;
      case BYCDisplaySize.medium:
        return FontWeight.w600;
      case BYCDisplaySize.large:
        return FontWeight.w700;
      case BYCDisplaySize.extraLarge:
        return FontWeight.w800;
    }
  }

  double _getIconSize() {
    switch (size) {
      case BYCDisplaySize.small:
        return 16;
      case BYCDisplaySize.medium:
        return 20;
      case BYCDisplaySize.large:
        return 24;
      case BYCDisplaySize.extraLarge:
        return 28;
    }
  }

  double _getSpacing() {
    switch (size) {
      case BYCDisplaySize.small:
        return 4;
      case BYCDisplaySize.medium:
        return 6;
      case BYCDisplaySize.large:
        return 8;
      case BYCDisplaySize.extraLarge:
        return 10;
    }
  }
}

/// BYC balance card for wallet display
class BYCBalanceCard extends StatelessWidget {
  final double balance;
  final double? pendingAmount;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showDetails;

  const BYCBalanceCard({
    Key? key,
    required this.balance,
    this.pendingAmount,
    this.subtitle,
    this.onTap,
    this.showDetails = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'BYC Balance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (onTap != null)
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white70,
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                BYCAmountDisplay(
                  amount: balance,
                  size: BYCDisplaySize.extraLarge,
                  textColor: Colors.white,
                  iconColor: Colors.white,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
                if (showDetails && pendingAmount != null && pendingAmount! > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      BYCAmountDisplay(
                        amount: pendingAmount!,
                        size: BYCDisplaySize.small,
                        textColor: Colors.orange,
                        prefix: 'Pending: ',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact BYC display for lists
class BYCAmountCompact extends StatelessWidget {
  final double amount;
  final bool showIcon;

  const BYCAmountCompact({
    Key? key,
    required this.amount,
    this.showIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BYCAmountDisplay(
      amount: amount,
      size: BYCDisplaySize.small,
      showIcon: showIcon,
    );
  }
}

/// BYC transaction display
class BYCTransactionDisplay extends StatelessWidget {
  final double amount;
  final String description;
  final DateTime timestamp;
  final BYCTransactionType type;
  final VoidCallback? onTap;

  const BYCTransactionDisplay({
    Key? key,
    required this.amount,
    required this.description,
    required this.timestamp,
    required this.type,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildTransactionIcon(),
      title: Text(
        description,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        _formatTimestamp(timestamp),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: BYCAmountDisplay(
        amount: amount,
        size: BYCDisplaySize.medium,
        isPositive: type == BYCTransactionType.received || type == BYCTransactionType.earned,
        prefix: _getPrefix(),
      ),
      onTap: onTap,
    );
  }

  Widget _buildTransactionIcon() {
    IconData icon;
    Color color;

    switch (type) {
      case BYCTransactionType.sent:
        icon = Icons.arrow_upward;
        color = const Color(0xFFF44336);
        break;
      case BYCTransactionType.received:
        icon = Icons.arrow_downward;
        color = const Color(0xFF4CAF50);
        break;
      case BYCTransactionType.earned:
        icon = Icons.star;
        color = const Color(0xFFFFB300);
        break;
      case BYCTransactionType.spent:
        icon = Icons.shopping_cart;
        color = const Color(0xFFFF9800);
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  String _getPrefix() {
    switch (type) {
      case BYCTransactionType.sent:
      case BYCTransactionType.spent:
        return '-';
      case BYCTransactionType.received:
      case BYCTransactionType.earned:
        return '+';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
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

/// BYC price display with conversion
class BYCPriceDisplay extends StatelessWidget {
  final double bycAmount;
  final double exchangeRate; // BYC to USD
  final String currency;

  const BYCPriceDisplay({
    Key? key,
    required this.bycAmount,
    required this.exchangeRate,
    this.currency = 'USD',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final convertedAmount = bycAmount * exchangeRate;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BYCAmountDisplay(
          amount: bycAmount,
          size: BYCDisplaySize.medium,
        ),
        const SizedBox(height: 2),
        Text(
          '≈ ${NumberFormat.currency(symbol: '\$').format(convertedAmount)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

/// Display size options
enum BYCDisplaySize {
  small,
  medium,
  large,
  extraLarge,
}

/// Transaction type enumeration
enum BYCTransactionType {
  sent,
  received,
  earned,
  spent,
}