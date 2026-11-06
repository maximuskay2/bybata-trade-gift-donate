import 'dart:convert';

/// Model for storing user's bank account details for withdrawals
class BankDetails {
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String accountType; // "Savings" or "Checking"
  final DateTime createdAt;
  final String id; // Unique identifier for the bank account

  const BankDetails({
    required this.bankName,
    required this.accountHolderName,
    required this.accountNumber,
    required this.accountType,
    required this.createdAt,
    required this.id,
  });

  /// Convert to JSON for API submission
  Map<String, dynamic> toJson() => {
    'bankName': bankName,
    'accountHolderName': accountHolderName,
    'accountNumber': accountNumber,
    'accountType': accountType,
  };

  /// Create from JSON response
  factory BankDetails.fromJson(Map<String, dynamic> json) {
    return BankDetails(
      bankName: json['bankName'] as String? ?? '',
      accountHolderName: json['accountHolderName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      accountType: json['accountType'] as String? ?? 'Savings',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      id: json['id'] as String? ?? '',
    );
  }

  /// Create a copy with modified fields
  BankDetails copyWith({
    String? bankName,
    String? accountHolderName,
    String? accountNumber,
    String? accountType,
    DateTime? createdAt,
    String? id,
  }) {
    return BankDetails(
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountType: accountType ?? this.accountType,
      createdAt: createdAt ?? this.createdAt,
      id: id ?? this.id,
    );
  }

  /// Validate bank details
  String? validate() {
    if (bankName.trim().isEmpty) return 'Bank name is required';
    if (accountHolderName.trim().isEmpty) return 'Account holder name is required';
    if (accountNumber.trim().isEmpty) return 'Account number is required';
    if (accountNumber.length < 8) return 'Account number must be at least 8 digits';
    return null;
  }

  @override
  String toString() => 
    '$accountHolderName - $bankName ($accountNumber)';
}

/// Model for conversion rate
class ConversionRate {
  final String fromCurrency; // "BYC"
  final String toCurrency; // "NGN" or "USD"
  final double rate;
  final DateTime updatedAt;

  const ConversionRate({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.updatedAt,
  });

  factory ConversionRate.fromJson(Map<String, dynamic> json) {
    return ConversionRate(
      fromCurrency: json['fromCurrency'] as String? ?? 'BYC',
      toCurrency: json['toCurrency'] as String? ?? 'USD',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Convert amount from BYC to target currency
  double convert(double amountInByc) => amountInByc * rate;

  @override
  String toString() => '1 BYC = $rate $toCurrency';
}
