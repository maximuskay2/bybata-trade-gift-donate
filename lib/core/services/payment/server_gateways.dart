import 'package:bybata/features/wallet/services/wallet_api.dart';
import 'payment_gateway_interface.dart';

class ServerPaystackGateway implements PaymentGatewayInterface {
  late WalletApi _api;
  bool _isTest = true;

  @override
  String get gatewayName => 'Paystack';

  @override
  Future<void> initialize({
    required String publicKey,
    required String secretKey,
    bool isTestMode = true,
  }) async {
    _api = await WalletApi.create();
    _isTest = isTestMode;
  }

  @override
  Future<PaymentResult> processPayment({
    required double amount,
    required String currency,
    required String userEmail,
    required String userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final amountByc = metadata?['amountByc'] is num
          ? (metadata!['amountByc'] as num).toDouble()
          : null;
      final res = await _api.createPaystackFunding(
        amount: amount,
        currency: currency,
        returnUrl: metadata?['returnUrl'] as String?,
        amountByc: amountByc,
      );
      final ref =
          (res['reference'] as String?) ??
          (res['data']?['reference'] as String?) ??
          'paystack_${DateTime.now().millisecondsSinceEpoch}';
      return PaymentResult.success(transactionReference: ref, metadata: res);
    } catch (e) {
      return PaymentResult.failure(
        errorMessage: 'Paystack init failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<PaymentVerificationResult> verifyPayment(
    String transactionReference,
  ) async {
    try {
      final res = await _api.verifyPaystackFunding(
        providerReference: transactionReference,
      );
      final ok = res['ok'] == true || res['verified'] == true;
      return PaymentVerificationResult(
        isValid: ok,
        amount: 0,
        currency: 'NGN',
        status: ok ? 'success' : 'pending',
        transactionReference: transactionReference,
        metadata: res,
      );
    } catch (_) {
      return const PaymentVerificationResult(
        isValid: false,
        amount: 0,
        currency: 'NGN',
        status: 'error',
      );
    }
  }

  @override
  List<String> getSupportedCurrencies() => ['NGN', 'GHS', 'KES', 'ZAR'];
}

class ServerStripeGateway implements PaymentGatewayInterface {
  late WalletApi _api;
  bool _isTest = true;

  @override
  String get gatewayName => 'Stripe';

  @override
  Future<void> initialize({
    required String publicKey,
    required String secretKey,
    bool isTestMode = true,
  }) async {
    _api = await WalletApi.create();
    _isTest = isTestMode;
  }

  @override
  Future<PaymentResult> processPayment({
    required double amount,
    required String currency,
    required String userEmail,
    required String userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final amountByc = metadata?['amountByc'] is num
          ? (metadata!['amountByc'] as num).toDouble()
          : null;
      final res = await _api.createStripeFunding(
        amountUsd: amount,
        returnUrl: metadata?['returnUrl'] as String?,
        amountByc: amountByc,
      );
      final ref =
          (res['sessionId'] as String?) ??
          (res['meta']?['providerReference'] as String?) ??
          (res['paymentIntentId'] as String?) ??
          (res['reference'] as String?) ??
          'stripe_${DateTime.now().millisecondsSinceEpoch}';
      return PaymentResult.success(transactionReference: ref, metadata: res);
    } catch (e) {
      return PaymentResult.failure(
        errorMessage: 'Stripe init failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<PaymentVerificationResult> verifyPayment(
    String transactionReference,
  ) async {
    try {
      final res = await _api.verifyStripeFunding(
        sessionId: transactionReference,
      );
      final ok = res['ok'] == true;
      return PaymentVerificationResult(
        isValid: ok,
        amount: 0,
        currency: 'USD',
        status: ok ? 'success' : 'pending',
        transactionReference: transactionReference,
        metadata: res,
      );
    } catch (_) {
      return const PaymentVerificationResult(
        isValid: false,
        amount: 0,
        currency: 'USD',
        status: 'error',
      );
    }
  }

  @override
  List<String> getSupportedCurrencies() => ['USD']; // Stripe: USD (backend accepts amountUsd)
}

class ServerPaypalGateway implements PaymentGatewayInterface {
  late WalletApi _api;
  bool _isTest = true;

  @override
  String get gatewayName => 'PayPal';

  @override
  Future<void> initialize({
    required String publicKey,
    required String secretKey,
    bool isTestMode = true,
  }) async {
    _api = await WalletApi.create();
    _isTest = isTestMode;
  }

  @override
  Future<PaymentResult> processPayment({
    required double amount,
    required String currency,
    required String userEmail,
    required String userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final amountByc = metadata?['amountByc'] is num
          ? (metadata!['amountByc'] as num).toDouble()
          : null;
      final res = await _api.createPayPalFunding(
        amountUsd: amount,
        returnUrl: metadata?['returnUrl'] as String?,
        amountByc: amountByc,
      );
      final ref =
          (res['orderId'] as String?) ??
          (res['meta']?['providerReference'] as String?) ??
          'paypal_${DateTime.now().millisecondsSinceEpoch}';
      return PaymentResult.success(transactionReference: ref, metadata: res);
    } catch (e) {
      return PaymentResult.failure(
        errorMessage: 'PayPal init failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<PaymentVerificationResult> verifyPayment(
    String transactionReference,
  ) async {
    try {
      final res = await _api.verifyPaypalFunding(orderId: transactionReference);
      final ok = res['ok'] == true;
      return PaymentVerificationResult(
        isValid: ok,
        amount: 0,
        currency: 'USD',
        status: ok ? 'success' : 'pending',
        transactionReference: transactionReference,
        metadata: res,
      );
    } catch (_) {
      return const PaymentVerificationResult(
        isValid: false,
        amount: 0,
        currency: 'USD',
        status: 'error',
      );
    }
  }

  @override
  List<String> getSupportedCurrencies() => ['USD']; // PayPal: USD (backend accepts amountUsd)
}

class ServerFlutterwaveGateway implements PaymentGatewayInterface {
  late WalletApi _api;
  bool _isTest = true;

  @override
  String get gatewayName => 'Flutterwave';

  @override
  Future<void> initialize({
    required String publicKey,
    required String secretKey,
    bool isTestMode = true,
  }) async {
    _api = await WalletApi.create();
    _isTest = isTestMode;
  }

  @override
  Future<PaymentResult> processPayment({
    required double amount,
    required String currency,
    required String userEmail,
    required String userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final amountByc = metadata?['amountByc'] is num
          ? (metadata!['amountByc'] as num).toDouble()
          : null;
      final res = await _api.createFlutterwaveFunding(
        amount: amount,
        currency: currency,
        returnUrl: metadata?['returnUrl'] as String?,
        amountByc: amountByc,
      );
      final ref =
          (res['reference'] as String?) ??
          (res['meta']?['tx_ref'] as String?) ??
          'flutterwave_${DateTime.now().millisecondsSinceEpoch}';
      return PaymentResult.success(transactionReference: ref, metadata: res);
    } catch (e) {
      return PaymentResult.failure(
        errorMessage: 'Flutterwave init failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<PaymentVerificationResult> verifyPayment(
    String transactionReference,
  ) async {
    try {
      final res = await _api.verifyFlutterwaveFunding(
        transactionId: transactionReference,
      );
      final ok = res['ok'] == true;
      return PaymentVerificationResult(
        isValid: ok,
        amount: 0,
        currency: 'NGN',
        status: ok ? 'success' : 'pending',
        transactionReference: transactionReference,
        metadata: res,
      );
    } catch (_) {
      return const PaymentVerificationResult(
        isValid: false,
        amount: 0,
        currency: 'NGN',
        status: 'error',
      );
    }
  }

  @override
  List<String> getSupportedCurrencies() =>
      ['NGN', 'GHS', 'KES', 'ZAR']; // Flutterwave: African currencies
}
