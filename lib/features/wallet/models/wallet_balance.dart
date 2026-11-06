class WalletBalance {
  final double balance;
  final double usdEquivalent;
  final String currency;
  final DateTime lastUpdated;
  final double conversionRate; // BYC to USD rate

  WalletBalance({
    this.balance = 0.0,
    this.usdEquivalent = 0.0,
    this.currency = 'BYC',
    DateTime? lastUpdated,
    this.conversionRate = 0.10, // 1 BYC = $0.10 USD (example rate)
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  // Formatted getters for UI display
  String get formattedBalance {
    if (balance >= 1000000) {
      return '${(balance / 1000000).toStringAsFixed(1)}M';
    } else if (balance >= 1000) {
      return '${(balance / 1000).toStringAsFixed(1)}K';
    } else {
      return balance.toStringAsFixed(2);
    }
  }

  String get fullFormattedBalance => balance.toStringAsFixed(2);

  String get formattedUsdEquivalent => usdEquivalent.toStringAsFixed(2);

  String get displayBalance => '$formattedBalance $currency';

  String get fullDisplayBalance => '$fullFormattedBalance $currency';

  String get usdDisplay => '\$${formattedUsdEquivalent} USD';

  bool get hasBalance => balance > 0;

  bool canAfford(double amount) => balance >= amount;

  // Calculate USD equivalent based on current balance and rate
  double get calculatedUsdEquivalent => balance * conversionRate;

  // Wallet status based on balance
  WalletStatus get status {
    if (balance == 0) return WalletStatus.empty;
    if (balance < 100) return WalletStatus.low;
    if (balance < 1000) return WalletStatus.medium;
    return WalletStatus.high;
  }

  String get statusMessage {
    switch (status) {
      case WalletStatus.empty:
        return 'Fund your wallet to get started';
      case WalletStatus.low:
        return 'Consider adding more BYC to your wallet';
      case WalletStatus.medium:
        return 'Good balance for regular activities';
      case WalletStatus.high:
        return 'Excellent balance for all features';
    }
  }

  // Methods for balance operations (for future use)
  WalletBalance addBalance(double amount) {
    return copyWith(
      balance: balance + amount,
      lastUpdated: DateTime.now(),
    );
  }

  WalletBalance subtractBalance(double amount) {
    return copyWith(
      balance: (balance - amount).clamp(0.0, double.infinity),
      lastUpdated: DateTime.now(),
    );
  }

  WalletBalance updateConversionRate(double newRate) {
    return copyWith(
      conversionRate: newRate,
      usdEquivalent: balance * newRate,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'balance': balance,
      'usdEquivalent': usdEquivalent,
      'currency': currency,
      'lastUpdated': lastUpdated.toIso8601String(),
      'conversionRate': conversionRate,
    };
  }

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      balance: (json['balance'] ?? 0.0).toDouble(),
      usdEquivalent: (json['usdEquivalent'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'BYC',
      lastUpdated: json['lastUpdated'] != null 
        ? DateTime.parse(json['lastUpdated'])
        : DateTime.now(),
      conversionRate: (json['conversionRate'] ?? 0.10).toDouble(),
    );
  }

  WalletBalance copyWith({
    double? balance,
    double? usdEquivalent,
    String? currency,
    DateTime? lastUpdated,
    double? conversionRate,
  }) {
    return WalletBalance(
      balance: balance ?? this.balance,
      usdEquivalent: usdEquivalent ?? this.usdEquivalent,
      currency: currency ?? this.currency,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      conversionRate: conversionRate ?? this.conversionRate,
    );
  }

  @override
  String toString() {
    return 'WalletBalance{balance: $balance $currency, usd: \$${usdEquivalent}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletBalance &&
        other.balance == balance &&
        other.currency == currency;
  }

  @override
  int get hashCode => balance.hashCode ^ currency.hashCode;
}

enum WalletStatus {
  empty,
  low,
  medium,
  high,
}

// Funding Package model for preset amounts
class FundingPackage {
  final String id;
  final String name;
  final double bycAmount;
  final double usdPrice;
  final String description;
  final bool isPopular;
  final double bonusPercentage;

  const FundingPackage({
    required this.id,
    required this.name,
    required this.bycAmount,
    required this.usdPrice,
    required this.description,
    this.isPopular = false,
    this.bonusPercentage = 0.0,
  });

  double get totalBYC => bycAmount + (bycAmount * bonusPercentage / 100);
  
  String get formattedBYC {
    if (totalBYC >= 1000) {
      return '${(totalBYC / 1000).toStringAsFixed(1)}K BYC';
    }
    return '${totalBYC.toStringAsFixed(0)} BYC';
  }

  String get formattedPrice => '\$${usdPrice.toStringAsFixed(2)}';
  
  String get bonusText => bonusPercentage > 0 
    ? '+${bonusPercentage.toStringAsFixed(0)}% Bonus' 
    : '';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bycAmount': bycAmount,
      'usdPrice': usdPrice,
      'description': description,
      'isPopular': isPopular,
      'bonusPercentage': bonusPercentage,
    };
  }

  factory FundingPackage.fromJson(Map<String, dynamic> json) {
    return FundingPackage(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      bycAmount: (json['bycAmount'] ?? 0.0).toDouble(),
      usdPrice: (json['usdPrice'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      isPopular: json['isPopular'] ?? false,
      bonusPercentage: (json['bonusPercentage'] ?? 0.0).toDouble(),
    );
  }
}