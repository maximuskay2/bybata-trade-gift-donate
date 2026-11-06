import 'package:flutter/material.dart';
import 'package:bybata/core/theme/app_theme.dart';

/// Enumeration for different transaction types in the BYC wallet
enum TransactionType {
  fund,
  send,
  receive,
  promotion,
  advert,
  conversion,
  refund,
  bonus,
  cashback,
  gift
}

/// Enumeration for transaction status
enum TransactionStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
  refunded
}

/// Enumeration for payment methods
enum PaymentMethodType {
  creditCard,
  debitCard,
  bankTransfer,
  paypal,
  applePay,
  googlePay,
  cryptocurrency,
  mobileWallet
}

/// Enumeration for promotion types
enum PromotionType {
  trade,
  gift,
  campaign,
  community,
  event,
  announcement
}

/// Enumeration for conversion currencies
enum CurrencyType {
  usd,
  eur,
  gbp,
  ngn,
  jpy,
  cad,
  aud,
  btc,
  eth
}

/// Main wallet balance model
class WalletBalance {
  final String userId;
  final double totalBalance;
  final double availableBalance;
  
  // Backward-compat getters for older tests
  double get amount => totalBalance;
  String get currencyCode => 'BYC';
  final double pendingBalance;
  final double promotionalBalance;
  final DateTime lastUpdated;
  final List<BalanceHistory> history;

  const WalletBalance({
    required this.userId,
    required this.totalBalance,
    required this.availableBalance,
    required this.pendingBalance,
    this.promotionalBalance = 0.0,
    required this.lastUpdated,
    this.history = const [],
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      userId: json['userId'],
      totalBalance: json['totalBalance']?.toDouble() ?? 0.0,
      availableBalance: json['availableBalance']?.toDouble() ?? 0.0,
      pendingBalance: json['pendingBalance']?.toDouble() ?? 0.0,
      promotionalBalance: json['promotionalBalance']?.toDouble() ?? 0.0,
      lastUpdated: DateTime.parse(json['lastUpdated']),
      history: (json['history'] as List?)
          ?.map((h) => BalanceHistory.fromJson(h))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'totalBalance': totalBalance,
    'availableBalance': availableBalance,
    'pendingBalance': pendingBalance,
    'promotionalBalance': promotionalBalance,
    'lastUpdated': lastUpdated.toIso8601String(),
    'history': history.map((h) => h.toJson()).toList(),
  };

  WalletBalance copyWith({
    double? totalBalance,
    double? availableBalance,
    double? pendingBalance,
    double? promotionalBalance,
    DateTime? lastUpdated,
    List<BalanceHistory>? history,
  }) {
    return WalletBalance(
      userId: userId,
      totalBalance: totalBalance ?? this.totalBalance,
      availableBalance: availableBalance ?? this.availableBalance,
      pendingBalance: pendingBalance ?? this.pendingBalance,
      promotionalBalance: promotionalBalance ?? this.promotionalBalance,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      history: history ?? this.history,
    );
  }
}

/// Balance history tracking for analytics
class BalanceHistory {
  final String id;
  final double amount;
  final DateTime timestamp;
  final TransactionType type;
  final String description;

  const BalanceHistory({
    required this.id,
    required this.amount,
    required this.timestamp,
    required this.type,
    required this.description,
  });

  factory BalanceHistory.fromJson(Map<String, dynamic> json) {
    return BalanceHistory(
      id: json['id'],
      amount: json['amount']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
      type: TransactionType.values.firstWhere(
        (e) => e.toString() == 'TransactionType.${json['type']}',
        orElse: () => TransactionType.fund,
      ),
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'timestamp': timestamp.toIso8601String(),
    'type': type.toString().split('.').last,
    'description': description,
  };
}

/// Transaction model for all BYC wallet transactions
class WalletTransaction {
  final String id;
  final String userId;
  final TransactionType type;
  final double amount;
  final double fee;
  final double netAmount;
  final TransactionStatus status;
  final String description;
  final DateTime timestamp;
  final String? recipientId;
  final String? recipientName;
  final String? senderId;
  final String? senderName;
  final String? referenceId;
  final Map<String, dynamic> metadata;
  final String? paymentMethodId;
  final String? promotionId;
  final String? transactionHash;
  final String? note;

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.fee = 0.0,
    required this.netAmount,
    required this.status,
    required this.description,
    required this.timestamp,
    this.recipientId,
    this.recipientName,
    this.senderId,
    this.senderName,
    this.referenceId,
    this.metadata = const {},
    this.paymentMethodId,
    this.promotionId,
    this.transactionHash,
    this.note,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'],
      userId: json['userId'],
      type: TransactionType.values.firstWhere(
        (e) => e.toString() == 'TransactionType.${json['type']}',
        orElse: () => TransactionType.fund,
      ),
      amount: json['amount']?.toDouble() ?? 0.0,
      fee: json['fee']?.toDouble() ?? 0.0,
      netAmount: json['netAmount']?.toDouble() ?? 0.0,
      status: TransactionStatus.values.firstWhere(
        (e) => e.toString() == 'TransactionStatus.${json['status']}',
        orElse: () => TransactionStatus.pending,
      ),
      description: json['description'],
      timestamp: DateTime.parse(json['timestamp']),
      recipientId: json['recipientId'],
      recipientName: json['recipientName'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      referenceId: json['referenceId'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      paymentMethodId: json['paymentMethodId'],
      promotionId: json['promotionId'],
      transactionHash: json['transactionHash'],
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.toString().split('.').last,
    'amount': amount,
    'fee': fee,
    'netAmount': netAmount,
    'status': status.toString().split('.').last,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
    'recipientId': recipientId,
    'recipientName': recipientName,
    'senderId': senderId,
    'senderName': senderName,
    'referenceId': referenceId,
    'metadata': metadata,
    'paymentMethodId': paymentMethodId,
    'promotionId': promotionId,
    'transactionHash': transactionHash,
    'note': note,
  };

  // Helper getters
  bool get isIncoming => type == TransactionType.receive || type == TransactionType.bonus || type == TransactionType.cashback;
  bool get isOutgoing => type == TransactionType.send || type == TransactionType.promotion || type == TransactionType.advert || type == TransactionType.fund;
  bool get isPending => status == TransactionStatus.pending || status == TransactionStatus.processing;
  bool get isCompleted => status == TransactionStatus.completed;
  bool get isFailed => status == TransactionStatus.failed || status == TransactionStatus.cancelled;

  Color get statusColor {
    switch (status) {
      case TransactionStatus.completed:
        return Colors.green;
      case TransactionStatus.pending:
      case TransactionStatus.processing:
        return Colors.orange;
      case TransactionStatus.failed:
      case TransactionStatus.cancelled:
        return Colors.red;
      case TransactionStatus.refunded:
        return AppColors.primary;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case TransactionType.fund:
        return Icons.add_circle;
      case TransactionType.send:
        return Icons.send;
      case TransactionType.receive:
        return Icons.call_received;
      case TransactionType.promotion:
        return Icons.trending_up;
      case TransactionType.advert:
        return Icons.campaign;
      case TransactionType.conversion:
        return Icons.swap_horiz;
      case TransactionType.refund:
        return Icons.refresh;
      case TransactionType.bonus:
        return Icons.stars;
      case TransactionType.cashback:
        return Icons.money_off;
      case TransactionType.gift:
        return Icons.card_giftcard;
    }
  }
}

class PromotionPlan {
  final String slug;
  final String title;
  final String type;
  final double amountByc;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool active;

  const PromotionPlan({
    required this.slug,
    required this.title,
    required this.type,
    required this.amountByc,
    this.startsAt,
    this.endsAt,
    this.active = true,
  });

  factory PromotionPlan.fromJson(Map<String, dynamic> json) {
    return PromotionPlan(
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'trade',
      amountByc: (json['amountBYC'] is num)
          ? (json['amountBYC'] as num).toDouble()
          : double.tryParse(json['amountBYC']?.toString() ?? '') ?? 0.0,
      startsAt: json['startsAt'] != null ? DateTime.tryParse(json['startsAt'].toString()) : null,
      endsAt: json['endsAt'] != null ? DateTime.tryParse(json['endsAt'].toString()) : null,
      active: json['active'] ?? true,
    );
  }
}

/// Payment method model
class PaymentMethod {
  final String id;
  final String userId;
  final PaymentMethodType type;
  final String name;
  final String displayName;
  final String? lastFour;
  final String? expiryDate;
  final String? brand;
  final bool isDefault;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastUsed;
  final Map<String, dynamic> metadata;

  const PaymentMethod({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
    required this.displayName,
    this.lastFour,
    this.expiryDate,
    this.brand,
    this.isDefault = false,
    this.isActive = true,
    required this.createdAt,
    this.lastUsed,
    this.metadata = const {},
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'],
      userId: json['userId'],
      type: PaymentMethodType.values.firstWhere(
        (e) => e.toString() == 'PaymentMethodType.${json['type']}',
        orElse: () => PaymentMethodType.creditCard,
      ),
      name: json['name'],
      displayName: json['displayName'],
      lastFour: json['lastFour'],
      expiryDate: json['expiryDate'],
      brand: json['brand'],
      isDefault: json['isDefault'] ?? false,
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      lastUsed: json['lastUsed'] != null ? DateTime.parse(json['lastUsed']) : null,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.toString().split('.').last,
    'name': name,
    'displayName': displayName,
    'lastFour': lastFour,
    'expiryDate': expiryDate,
    'brand': brand,
    'isDefault': isDefault,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'lastUsed': lastUsed?.toIso8601String(),
    'metadata': metadata,
  };

  IconData get icon {
    switch (type) {
      case PaymentMethodType.creditCard:
      case PaymentMethodType.debitCard:
        return Icons.credit_card;
      case PaymentMethodType.bankTransfer:
        return Icons.account_balance;
      case PaymentMethodType.paypal:
        return Icons.payment;
      case PaymentMethodType.applePay:
        return Icons.apple;
      case PaymentMethodType.googlePay:
        return Icons.payment;
      case PaymentMethodType.cryptocurrency:
        return Icons.currency_bitcoin;
      case PaymentMethodType.mobileWallet:
        return Icons.phone_android;
    }
  }
}

/// Promotion model for boosting content visibility
class WalletPromotion {
  final String id;
  final String userId;
  final PromotionType type;
  final String title;
  final String description;
  final double bycCost;
  final double reach;
  final double engagement;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String? targetId; // ID of the promoted content
  final String? targetType; // trade, gift, campaign, community
  final Map<String, dynamic> metrics;
  final List<String> targetAudience;

  const WalletPromotion({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.bycCost,
    this.reach = 0.0,
    this.engagement = 0.0,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.targetId,
    this.targetType,
    this.metrics = const {},
    this.targetAudience = const [],
  });

  factory WalletPromotion.fromJson(Map<String, dynamic> json) {
    return WalletPromotion(
      id: json['id'],
      userId: json['userId'],
      type: PromotionType.values.firstWhere(
        (e) => e.toString() == 'PromotionType.${json['type']}',
        orElse: () => PromotionType.trade,
      ),
      title: json['title'],
      description: json['description'],
      bycCost: json['bycCost']?.toDouble() ?? 0.0,
      reach: json['reach']?.toDouble() ?? 0.0,
      engagement: json['engagement']?.toDouble() ?? 0.0,
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      isActive: json['isActive'] ?? true,
      targetId: json['targetId'],
      targetType: json['targetType'],
      metrics: Map<String, dynamic>.from(json['metrics'] ?? {}),
      targetAudience: List<String>.from(json['targetAudience'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.toString().split('.').last,
    'title': title,
    'description': description,
    'bycCost': bycCost,
    'reach': reach,
    'engagement': engagement,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'isActive': isActive,
    'targetId': targetId,
    'targetType': targetType,
    'metrics': metrics,
    'targetAudience': targetAudience,
  };

  bool get isExpired => DateTime.now().isAfter(endDate);
  bool get isStarted => DateTime.now().isAfter(startDate);
  Duration get remainingTime => endDate.difference(DateTime.now());
  
  double get engagementRate => reach > 0 ? (engagement / reach) * 100 : 0.0;
  
  IconData get icon {
    switch (type) {
      case PromotionType.trade:
        return Icons.swap_horiz;
      case PromotionType.gift:
        return Icons.card_giftcard;
      case PromotionType.campaign:
        return Icons.campaign;
      case PromotionType.community:
        return Icons.groups;
      case PromotionType.event:
        return Icons.event;
      case PromotionType.announcement:
        return Icons.announcement;
    }
  }
}

/// Conversion rate model for different currencies
class ConversionRate {
  final CurrencyType fromCurrency;
  final CurrencyType toCurrency;
  final double rate;
  final double buyRate;
  final double sellRate;
  final DateTime lastUpdated;
  final double change24h;
  final double changePercent24h;
  final double high24h;
  final double low24h;

  const ConversionRate({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.buyRate,
    required this.sellRate,
    required this.lastUpdated,
    this.change24h = 0.0,
    this.changePercent24h = 0.0,
    this.high24h = 0.0,
    this.low24h = 0.0,
  });

  factory ConversionRate.fromJson(Map<String, dynamic> json) {
    return ConversionRate(
      fromCurrency: CurrencyType.values.firstWhere(
        (e) => e.toString() == 'CurrencyType.${json['fromCurrency']}',
        orElse: () => CurrencyType.usd,
      ),
      toCurrency: CurrencyType.values.firstWhere(
        (e) => e.toString() == 'CurrencyType.${json['toCurrency']}',
        orElse: () => CurrencyType.usd,
      ),
      rate: json['rate']?.toDouble() ?? 0.0,
      buyRate: json['buyRate']?.toDouble() ?? 0.0,
      sellRate: json['sellRate']?.toDouble() ?? 0.0,
      lastUpdated: DateTime.parse(json['lastUpdated']),
      change24h: json['change24h']?.toDouble() ?? 0.0,
      changePercent24h: json['changePercent24h']?.toDouble() ?? 0.0,
      high24h: json['high24h']?.toDouble() ?? 0.0,
      low24h: json['low24h']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'fromCurrency': fromCurrency.toString().split('.').last,
    'toCurrency': toCurrency.toString().split('.').last,
    'rate': rate,
    'buyRate': buyRate,
    'sellRate': sellRate,
    'lastUpdated': lastUpdated.toIso8601String(),
    'change24h': change24h,
    'changePercent24h': changePercent24h,
    'high24h': high24h,
    'low24h': low24h,
  };

  String get fromCurrencySymbol => _getCurrencySymbol(fromCurrency);
  String get toCurrencySymbol => _getCurrencySymbol(toCurrency);
  
  bool get isPositiveChange => changePercent24h > 0;
  Color get changeColor => isPositiveChange ? Colors.green : Colors.red;

  static String _getCurrencySymbol(CurrencyType currency) {
    switch (currency) {
      case CurrencyType.usd:
        return '\$';
      case CurrencyType.eur:
        return '€';
      case CurrencyType.gbp:
        return '£';
      case CurrencyType.ngn:
        return '₦';
      case CurrencyType.jpy:
        return '¥';
      case CurrencyType.cad:
        return 'C\$';
      case CurrencyType.aud:
        return 'A\$';
      case CurrencyType.btc:
        return '₿';
      case CurrencyType.eth:
        return 'Ξ';
    }
  }

  String get fromCurrencyName => _getCurrencyName(fromCurrency);
  String get toCurrencyName => _getCurrencyName(toCurrency);

  static String _getCurrencyName(CurrencyType currency) {
    switch (currency) {
      case CurrencyType.usd:
        return 'US Dollar';
      case CurrencyType.eur:
        return 'Euro';
      case CurrencyType.gbp:
        return 'British Pound';
      case CurrencyType.ngn:
        return 'Nigerian Naira';
      case CurrencyType.jpy:
        return 'Japanese Yen';
      case CurrencyType.cad:
        return 'Canadian Dollar';
      case CurrencyType.aud:
        return 'Australian Dollar';
      case CurrencyType.btc:
        return 'Bitcoin';
      case CurrencyType.eth:
        return 'Ethereum';
    }
  }
}

/// Wallet contact model for easy sending
class WalletContact {
  final String id;
  final String userId;
  final String contactUserId;
  final String contactName;
  final String contactEmail;
  final String? contactPhone;
  final String? contactAvatar;
  final int transactionCount;
  final double totalSent;
  final double totalReceived;
  final DateTime lastTransaction;
  final DateTime createdAt;
  final bool isFavorite;

  const WalletContact({
    required this.id,
    required this.userId,
    required this.contactUserId,
    required this.contactName,
    required this.contactEmail,
    this.contactPhone,
    this.contactAvatar,
    this.transactionCount = 0,
    this.totalSent = 0.0,
    this.totalReceived = 0.0,
    required this.lastTransaction,
    required this.createdAt,
    this.isFavorite = false,
  });

  factory WalletContact.fromJson(Map<String, dynamic> json) {
    return WalletContact(
      id: json['id'],
      userId: json['userId'],
      contactUserId: json['contactUserId'],
      contactName: json['contactName'],
      contactEmail: json['contactEmail'],
      contactPhone: json['contactPhone'],
      contactAvatar: json['contactAvatar'],
      transactionCount: json['transactionCount'] ?? 0,
      totalSent: json['totalSent']?.toDouble() ?? 0.0,
      totalReceived: json['totalReceived']?.toDouble() ?? 0.0,
      lastTransaction: DateTime.parse(json['lastTransaction']),
      createdAt: DateTime.parse(json['createdAt']),
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'contactUserId': contactUserId,
    'contactName': contactName,
    'contactEmail': contactEmail,
    'contactPhone': contactPhone,
    'contactAvatar': contactAvatar,
    'transactionCount': transactionCount,
    'totalSent': totalSent,
    'totalReceived': totalReceived,
    'lastTransaction': lastTransaction.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'isFavorite': isFavorite,
  };
}