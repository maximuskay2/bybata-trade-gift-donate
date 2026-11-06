import 'package:flutter/foundation.dart';
import 'payment_gateway_interface.dart';
import 'server_gateways.dart';

/// Central payment manager for handling wallet funding across multiple gateways
class PaymentManager extends ChangeNotifier {
  // Payment gateways
  final Map<PaymentGateway, PaymentGatewayInterface> _gateways = {};
  
  // Configuration
  bool _isInitialized = false;
  bool _isTestMode = true;
  
  // Current state
  bool _isProcessing = false;
  String? _errorMessage;
  PaymentResult? _lastPaymentResult;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isTestMode => _isTestMode;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  PaymentResult? get lastPaymentResult => _lastPaymentResult;
  
  List<PaymentGateway> get availableGateways => _gateways.keys.toList();

  /// Initialize all payment gateways with their configurations
  Future<void> initialize({
    required bool isTestMode,
    Map<PaymentGateway, PaymentConfig>? configs,
  }) async {
    _isTestMode = isTestMode;
    _isProcessing = true;
    notifyListeners();

    try {
      _gateways.clear();

      if (configs != null && configs.isNotEmpty) {
        for (final entry in configs.entries) {
          final gateway = entry.key;
          final cfg = entry.value;
          PaymentGatewayInterface? impl;
          switch (gateway) {
            case PaymentGateway.paystack:
              impl = ServerPaystackGateway();
              break;
            case PaymentGateway.stripe:
              impl = ServerStripeGateway();
              break;
            case PaymentGateway.flutterwave:
              impl = ServerFlutterwaveGateway();
              break;
            case PaymentGateway.paypal:
              impl = ServerPaypalGateway();
              break;
          }
          if (impl != null) {
            await impl.initialize(publicKey: cfg.publicKey, secretKey: cfg.secretKey, isTestMode: isTestMode);
            _gateways[gateway] = impl;
          }
        }
      }

      _isInitialized = true;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Payment gateway initialization failed: ${e.toString()}';
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  

  /// Process payment using specified gateway
  Future<PaymentResult> processPayment({
    required PaymentGateway gateway,
    required double amount,
    required String currency,
    required String userEmail,
    required String userId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) {
      return PaymentResult.failure(
        errorMessage: 'Payment manager not initialized',
      );
    }

    if (!_gateways.containsKey(gateway)) {
      return PaymentResult.failure(
        errorMessage: 'Gateway ${gateway.displayName} not available',
      );
    }

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final gatewayInterface = _gateways[gateway]!;
      
      // Validate currency support
      if (!gatewayInterface.getSupportedCurrencies().contains(currency.toUpperCase())) {
        return PaymentResult.failure(
          errorMessage: '${gateway.displayName} does not support $currency',
        );
      }

      final result = await gatewayInterface.processPayment(
        amount: amount,
        currency: currency,
        userEmail: userEmail,
        userId: userId,
        metadata: {
          'gateway': gateway.name,
          'timestamp': DateTime.now().toIso8601String(),
          ...?metadata,
        },
      );

      _lastPaymentResult = result;
      
      if (!result.isSuccess) {
        _errorMessage = result.errorMessage;
      }

      return result;
    } catch (e) {
      final result = PaymentResult.failure(
        errorMessage: 'Payment processing failed: ${e.toString()}',
      );
      _lastPaymentResult = result;
      _errorMessage = result.errorMessage;
      return result;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Verify payment using the gateway that processed it
  Future<PaymentVerificationResult> verifyPayment({
    required PaymentGateway gateway,
    required String transactionReference,
  }) async {
    if (!_isInitialized || !_gateways.containsKey(gateway)) {
      return PaymentVerificationResult(
        isValid: false,
        amount: 0,
        currency: 'USD',
        status: 'error',
      );
    }

    try {
      final gatewayInterface = _gateways[gateway]!;
      return await gatewayInterface.verifyPayment(transactionReference);
    } catch (e) {
      return PaymentVerificationResult(
        isValid: false,
        amount: 0,
        currency: 'USD',
        status: 'error',
      );
    }
  }

  /// Get recommended gateway for currency.
  /// NGN, GHS, KES, ZAR → prefer Paystack then Flutterwave
  /// USD and other → prefer Stripe then PayPal
  PaymentGateway? getRecommendedGateway(String currency) {
    currency = currency.toUpperCase();
    const africanCurrencies = ['NGN', 'GHS', 'KES', 'ZAR'];

    if (africanCurrencies.contains(currency)) {
      if (_gateways.containsKey(PaymentGateway.paystack) &&
          _gateways[PaymentGateway.paystack]!.getSupportedCurrencies().contains(currency)) {
        return PaymentGateway.paystack;
      }
      if (_gateways.containsKey(PaymentGateway.flutterwave)) {
        return PaymentGateway.flutterwave;
      }
    }

    // USD and other global currencies → Stripe then PayPal
    if (_gateways.containsKey(PaymentGateway.stripe)) {
      return PaymentGateway.stripe;
    }
    if (_gateways.containsKey(PaymentGateway.paypal)) {
      return PaymentGateway.paypal;
    }

    // Fallback: any gateway that supports the currency
    for (final entry in _gateways.entries) {
      if (entry.value.getSupportedCurrencies().contains(currency)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Get supported currencies across all gateways
  List<String> getAllSupportedCurrencies() {
    final currencies = <String>{};
    
    for (final gateway in _gateways.values) {
      currencies.addAll(gateway.getSupportedCurrencies());
    }
    
    return currencies.toList()..sort();
  }

  /// Get gateways that support a specific currency
  List<PaymentGateway> getGatewaysForCurrency(String currency) {
    currency = currency.toUpperCase();
    final supportedGateways = <PaymentGateway>[];
    
    for (final entry in _gateways.entries) {
      if (entry.value.getSupportedCurrencies().contains(currency)) {
        supportedGateways.add(entry.key);
      }
    }
    
    return supportedGateways;
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Get gateway interface for advanced operations
  PaymentGatewayInterface? getGateway(PaymentGateway gateway) {
    return _gateways[gateway];
  }
}

/// Payment configuration for each gateway
class PaymentConfig {
  final String publicKey;
  final String secretKey;
  final Map<String, dynamic>? additionalConfig;

  const PaymentConfig({
    required this.publicKey,
    required this.secretKey,
    this.additionalConfig,
  });
}

/// Default payment configurations (for testing)
class PaymentConfigs {
  static Map<PaymentGateway, PaymentConfig> getTestConfigs() {
    return {};
  }

  static Map<PaymentGateway, PaymentConfig> getProductionConfigs() {
    return {};
  }
}
