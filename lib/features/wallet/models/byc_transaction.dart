import 'package:flutter/material.dart';
import 'package:bybata/core/theme/app_theme.dart';

enum TransactionType {
  funding('Funding', Icons.add_circle, Colors.green),
  gift('Gift', Icons.card_giftcard, Colors.pink),
  promotion('Promotion', Icons.trending_up, Colors.orange),
  transfer('Transfer', Icons.send, AppColors.primary),
  reward('Reward', Icons.star, Colors.amber),
  refund('Refund', Icons.refresh, Colors.purple);

  const TransactionType(this.displayName, this.icon, this.color);
  final String displayName;
  final IconData icon;
  final Color color;
}

class BYCTransaction {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
  final TransactionType type;
  final DateTime createdAt;
  final String? reference;
  final String? recipientId;
  final String? recipientName;
  final Map<String, dynamic>? metadata;

  BYCTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.type,
    required this.createdAt,
    this.reference,
    this.recipientId,
    this.recipientName,
    this.metadata,
  });

  // Getters for UI display
  String get formattedAmount => amount.toStringAsFixed(2);
  
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  String get formattedDateTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays == 0) {
      return 'Today ${_formatTime(createdAt)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${_formatTime(createdAt)}';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year} ${_formatTime(createdAt)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  IconData get icon => type.icon;
  Color get color => type.color;

  String get displayTitle {
    switch (type) {
      case TransactionType.funding:
        return isCredit ? 'Wallet Funded' : 'Funding Fee';
      case TransactionType.gift:
        return isCredit ? 'Received Gift' : 'Sent Gift';
      case TransactionType.promotion:
        return 'Promoted Item';
      case TransactionType.transfer:
        return isCredit ? 'Received Transfer' : 'Sent Transfer';
      case TransactionType.reward:
        return 'Earned Reward';
      case TransactionType.refund:
        return 'Refund Received';
    }
  }

  String get transactionSign => isCredit ? '+' : '-';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'amount': amount,
      'isCredit': isCredit,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'reference': reference,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'metadata': metadata,
    };
  }

  factory BYCTransaction.fromJson(Map<String, dynamic> json) {
    return BYCTransaction(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      isCredit: json['isCredit'] ?? false,
      type: TransactionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TransactionType.transfer,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      reference: json['reference'],
      recipientId: json['recipientId'],
      recipientName: json['recipientName'],
      metadata: json['metadata'],
    );
  }

  BYCTransaction copyWith({
    String? id,
    String? title,
    String? subtitle,
    double? amount,
    bool? isCredit,
    TransactionType? type,
    DateTime? createdAt,
    String? reference,
    String? recipientId,
    String? recipientName,
    Map<String, dynamic>? metadata,
  }) {
    return BYCTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      amount: amount ?? this.amount,
      isCredit: isCredit ?? this.isCredit,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      reference: reference ?? this.reference,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'BYCTransaction{id: $id, title: $title, amount: $amount, type: ${type.name}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BYCTransaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}