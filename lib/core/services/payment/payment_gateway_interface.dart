/// Payment gateway interface for wallet funding
/// 
/// This interface defines the common operations that all payment gateways
/// must implement for funding the BYC wallet.

abstract class PaymentGatewayInterface {
  /// Initialize the payment gateway with configuration
  Future<void> initialize({
    required String publicKey,
    required String secretKey,
    bool isTestMode = true,
  });

  /// Process a payment for wallet funding
  /// 
  /// Returns the transaction reference if successful, null if failed
  Future<PaymentResult> processPayment({
    required double amount,
    required String currency,
    required String userEmail,
    required String userId,
    Map<String, dynamic>? metadata,
  });

  /// Verify a payment transaction
  Future<PaymentVerificationResult> verifyPayment(String transactionReference);

  /// Get supported currencies for this payment gateway
  List<String> getSupportedCurrencies();

  /// Get the gateway name
  String get gatewayName;
}

/// Payment result from processing payment
class PaymentResult {
  final bool isSuccess;
  final String? transactionReference;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  const PaymentResult({
    required this.isSuccess,
    this.transactionReference,
    this.errorMessage,
    this.metadata,
  });

  factory PaymentResult.success({
    required String transactionReference,
    Map<String, dynamic>? metadata,
  }) {
    return PaymentResult(
      isSuccess: true,
      transactionReference: transactionReference,
      metadata: metadata,
    );
  }

  factory PaymentResult.failure({
    required String errorMessage,
    Map<String, dynamic>? metadata,
  }) {
    return PaymentResult(
      isSuccess: false,
      errorMessage: errorMessage,
      metadata: metadata,
    );
  }
}

/// Payment verification result
class PaymentVerificationResult {
  final bool isValid;
  final double amount;
  final String currency;
  final String status;
  final String? transactionReference;
  final DateTime? paidAt;
  final Map<String, dynamic>? metadata;

  const PaymentVerificationResult({
    required this.isValid,
    required this.amount,
    required this.currency,
    required this.status,
    this.transactionReference,
    this.paidAt,
    this.metadata,
  });

  bool get isSuccessful => isValid && status.toLowerCase() == 'success';
}

/// Supported payment gateways
enum PaymentGateway {
  paystack,
  stripe,
  flutterwave,
  paypal,
}

extension PaymentGatewayExtension on PaymentGateway {
  String get displayName {
    switch (this) {
      case PaymentGateway.paystack:
        return 'Paystack';
      case PaymentGateway.stripe:
        return 'Stripe';
      case PaymentGateway.flutterwave:
        return 'Flutterwave';
      case PaymentGateway.paypal:
        return 'PayPal';
    }
  }

  List<String> get supportedCurrencies {
    switch (this) {
      case PaymentGateway.paystack:
        return ['NGN', 'USD', 'GHS', 'ZAR'];
      case PaymentGateway.stripe:
        return ['USD', 'EUR', 'GBP', 'CAD', 'AUD'];
      case PaymentGateway.flutterwave:
        return ['NGN', 'USD', 'EUR', 'GBP', 'GHS', 'KES', 'UGX', 'ZAR'];
      case PaymentGateway.paypal:
        return ['USD', 'EUR', 'GBP', 'CAD', 'AUD'];
    }
  }
}