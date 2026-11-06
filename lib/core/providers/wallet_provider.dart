import 'package:flutter/foundation.dart';
import '../models/app_models.dart';
import '../services/payment/payment_manager.dart';
import 'package:bybata/features/wallet/services/wallet_api.dart';
import 'package:bybata/features/wallet/services/wallet_service.dart';
import '../services/payment/payment_gateway_interface.dart';
import '../utils/network_error_message.dart';

class WalletProvider extends ChangeNotifier {
  // Wallet data
  Wallet? _wallet;
  List<BYCTransaction> _transactions = [];
  List<BYCTransaction> _filteredTransactions = [];

  // Payment integration
  PaymentManager? _paymentManager;
  bool _paymentInitialized = false;

  // UI state
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasMoreTransactions = true;
  int _currentPage = 1;

  // Filters
  TransactionType? _selectedType;
  TransactionStatus? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;
  String _sortBy = 'newest'; // newest, oldest, amount_high, amount_low

  // Exchange rates (BYC → fiat). Prefer API; used for display estimates only.
  double _bycToUsdRate = 0;
  Map<String, double> _exchangeRates = {};

  // Getters
  Wallet? get wallet => _wallet;
  List<BYCTransaction> get transactions => List.unmodifiable(_transactions);
  List<BYCTransaction> get filteredTransactions =>
      List.unmodifiable(_filteredTransactions);

  double get bycBalance => _wallet?.bycBalance ?? 0.0;
  double get pendingBalance => _wallet?.pendingBalance ?? 0.0;
  double get totalBalance => _wallet?.totalBalance ?? 0.0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMoreTransactions => _hasMoreTransactions;
  int get currentPage => _currentPage;

  TransactionType? get selectedType => _selectedType;
  TransactionStatus? get selectedStatus => _selectedStatus;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String get sortBy => _sortBy;

  double get bycToUsdRate => _bycToUsdRate;
  Map<String, double> get exchangeRates => Map.unmodifiable(_exchangeRates);

  // Payment getters
  PaymentManager? get paymentManager => _paymentManager;
  bool get isPaymentInitialized => _paymentInitialized;
  List<PaymentGateway> get availablePaymentGateways =>
      _paymentManager?.availableGateways ?? [];

  // Transaction type statistics
  Map<TransactionType, double> get transactionTypeStats {
    final stats = <TransactionType, double>{};

    for (final type in TransactionType.values) {
      final typeTransactions = _transactions.where((t) => t.type == type);
      final total = typeTransactions.fold<double>(
        0,
        (sum, t) => sum + t.amount,
      );
      if (total > 0) stats[type] = total;
    }

    return stats;
  }

  // Monthly spending
  Map<String, double> get monthlySpending {
    final spending = <String, double>{};
    final now = DateTime.now();

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = '${month.month}/${month.year}';

      final monthTransactions = _transactions.where((t) {
        return t.createdAt.year == month.year &&
            t.createdAt.month == month.month &&
            (t.type == TransactionType.sent ||
                t.type == TransactionType.purchase);
      });

      final total = monthTransactions.fold<double>(
        0,
        (sum, t) => sum + t.amount,
      );
      spending[monthKey] = total;
    }

    return spending;
  }

  // Initialize wallet provider
  Future<void> initializeWallet(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadWallet(userId);
      await loadTransactions();
      await _initializePaymentGateways();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t load your wallet. Please try again.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Initialize payment gateways
  Future<void> _initializePaymentGateways() async {
    try {
      _paymentManager = PaymentManager();
      // Auto-load public gateway configs from API (test mode by default)
      final api = await WalletApi.create();
      final items = await api.getPublicGatewayConfigs(mode: 'test');
      final configs = <PaymentGateway, PaymentConfig>{};
      for (final item in items) {
        final gw = (item['gateway'] as String?) ?? '';
        final pk = (item['publicKey'] as String?) ?? '';
        if (pk.isEmpty) continue;
        PaymentGateway? pg;
        switch (gw) {
          case 'paystack':
            pg = PaymentGateway.paystack;
            break;
          case 'stripe':
            pg = PaymentGateway.stripe;
            break;
          case 'flutterwave':
            pg = PaymentGateway.flutterwave;
            break;
          case 'paypal':
            pg = PaymentGateway.paypal;
            break;
          default:
            pg = null;
        }
        if (pg != null) {
          configs[pg] = PaymentConfig(publicKey: pk, secretKey: '');
        }
      }
      if (configs.isEmpty) {
        configs[PaymentGateway.paystack] = const PaymentConfig(
          publicKey: 'pk_test_placeholder',
          secretKey: '',
        );
        configs[PaymentGateway.stripe] = const PaymentConfig(
          publicKey: 'pk_test_placeholder',
          secretKey: '',
        );
        configs[PaymentGateway.paypal] = const PaymentConfig(
          publicKey: 'pk_test_placeholder',
          secretKey: '',
        );
      }
      await _paymentManager!.initialize(isTestMode: true, configs: configs);

      _paymentInitialized = true;
    } catch (e) {
      _paymentInitialized = false;
      // Don't fail wallet initialization if payment setup fails
      debugPrint('Payment gateway initialization failed: $e');
    }
  }

  // Load wallet data
  Future<void> _loadWallet(String userId) async {
    try {
      final ws = WalletService();
      // Initialize if not already loaded
      if (ws.currentBalance == null || ws.currentBalance!.userId != userId) {
        await ws.initializeWallet(userId);
      }
      final cb = ws.currentBalance;
      final byc = cb?.availableBalance ?? 0.0;
      final pending = cb?.pendingBalance ?? 0.0;
      _wallet = Wallet(
        id: 'wallet_$userId',
        userId: userId,
        bycBalance: byc,
        pendingBalance: pending,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to load wallet: ${e.toString()}');
    }
  }

  // Load transactions from the real wallet API (no mock history).
  Future<void> loadTransactions({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    _isLoading = true;
    if (refresh) {
      _currentPage = 1;
      _hasMoreTransactions = true;
    }
    notifyListeners();

    try {
      final api = await WalletApi.create();
      final items = await api.getTransactions(page: _currentPage, size: 20);
      final newTransactions = items
          .map((raw) => _mapApiTransaction(Map<String, dynamic>.from(raw as Map)))
          .toList();

      if (refresh) {
        _transactions = newTransactions;
      } else {
        _transactions.addAll(newTransactions);
      }

      _hasMoreTransactions = newTransactions.length >= 20;
      if (newTransactions.isNotEmpty) {
        _currentPage++;
      }

      _applyFilters();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t load wallet history. Please try again.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  BYCTransaction _mapApiTransaction(Map<String, dynamic> t) {
    final typeStr = (t['type'] as String?)?.toUpperCase() ?? '';
    final statusStr = (t['status'] as String?)?.toUpperCase() ?? '';
    TransactionType type;
    switch (typeStr) {
      case 'SEND':
        type = TransactionType.sent;
        break;
      case 'RECEIVE':
        type = TransactionType.received;
        break;
      case 'REFUND':
        type = TransactionType.refund;
        break;
      case 'BONUS':
      case 'CASHBACK':
        type = TransactionType.reward;
        break;
      case 'PROMOTION':
      case 'ADVERT':
        type = TransactionType.purchase;
        break;
      case 'FUND':
      default:
        type = TransactionType.received;
        break;
    }
    TransactionStatus status;
    switch (statusStr) {
      case 'SUCCESS':
        status = TransactionStatus.completed;
        break;
      case 'PENDING':
        status = TransactionStatus.pending;
        break;
      case 'FAILED':
        status = TransactionStatus.failed;
        break;
      default:
        status = TransactionStatus.pending;
        break;
    }
    final rawAmount = t['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse('$rawAmount') ?? 0.0;
    final createdAt = t['createdAt'] ?? t['timestamp'];
    final memo = (t['memo'] as String?) ??
        (t['description'] as String?) ??
        typeStr;
    return BYCTransaction(
      id: t['id']?.toString() ?? 'txn_${DateTime.now().millisecondsSinceEpoch}',
      title: memo,
      description: memo,
      amount: amount.abs(),
      currency: 'BYC',
      type: type,
      status: status,
      fromUserId: t['senderId']?.toString(),
      toUserId: t['recipientId']?.toString(),
      reference: t['referenceId']?.toString() ?? t['idempotencyKey']?.toString(),
      createdAt: createdAt is String
          ? DateTime.tryParse(createdAt) ?? DateTime.now()
          : DateTime.now(),
      metadata: Map<String, dynamic>.from(t['metadata'] as Map? ?? const {}),
    );
  }

  // Send BYC via real transfer API
  Future<bool> sendBYC({
    required double amount,
    required String recipientAddress,
    required String description,
    String? recipientId,
    String? recipientName,
    String? reference,
    Map<String, dynamic>? metadata,
  }) async {
    if (amount <= 0 || amount > bycBalance) {
      _errorMessage = 'Invalid amount or insufficient balance';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final api = await WalletApi.create();
      final to = recipientId ?? recipientAddress;
      final looksLikeEmail = to.contains('@');
      await api.transfer(
        toUserId: looksLikeEmail ? null : to,
        toEmail: looksLikeEmail ? to : null,
        amountByc: amount,
        memo: description,
      );

      final userId = _wallet?.userId;
      if (userId != null) {
        await _loadWallet(userId);
      }
      await loadTransactions(refresh: true);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t send BYC. Please try again.',
      );
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Incoming BYC is credited by the transfer/webhook APIs — refresh only.
  Future<bool> receiveBYC({
    required String senderId,
    required String senderName,
    required double amount,
    String? description,
    String? reference,
  }) async {
    try {
      final userId = _wallet?.userId;
      if (userId == null) {
        _errorMessage = 'Wallet not loaded';
        notifyListeners();
        return false;
      }
      await _loadWallet(userId);
      await loadTransactions(refresh: true);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = NetworkErrorMessage.from(e, fallback: 'Couldn\'t refresh wallet. Please try again.');
      notifyListeners();
      return false;
    }
  }

  // Add funds via payment gateway
  Future<bool> addFundsViaGateway({
    required double fiatAmount,
    required String currency,
    required PaymentGateway gateway,
    required String userEmail,
    Map<String, dynamic>? metadata,
  }) async {
    if (fiatAmount <= 0) {
      _errorMessage = 'Invalid deposit amount';
      notifyListeners();
      return false;
    }

    if (!_paymentInitialized || _paymentManager == null) {
      _errorMessage = 'Payment system not initialized';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Process payment via selected gateway - just get authorization URL
      final paymentResult = await _paymentManager!.processPayment(
        gateway: gateway,
        amount: fiatAmount,
        currency: currency,
        userEmail: userEmail,
        userId: _wallet!.userId,
        metadata: {
          'purpose': 'wallet_funding',
          'expected_byc': convertToBYC(fiatAmount, currency),
          ...?metadata,
        },
      );

      if (paymentResult.isSuccess) {
        // Return success - frontend will open WebView with authorization URL
        // Payment verification happens LATER when WebView redirects to callback endpoint
        // The callback endpoint will:
        // 1. Verify with provider
        // 2. Credit wallet
        // 3. Update transaction to SUCCESS
        // 4. Send email
        // Frontend will then refresh wallet from server
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage =
            paymentResult.errorMessage ?? 'Payment processing failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = NetworkErrorMessage.from(e, fallback: 'Couldn\'t complete that. Please try again.');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Legacy add funds method (for backwards compatibility)
  Future<bool> addFunds(double amount, String method) async {
    // Convert to new method - assume USD and Stripe for legacy calls
    return addFundsViaGateway(
      fiatAmount: amount,
      currency: 'USD',
      gateway: PaymentGateway.stripe,
      userEmail: 'user@example.com', // This should come from user context
      metadata: {'legacy_method': method},
    );
  }

  // Withdraw funds via real withdrawal request API
  Future<bool> withdrawFunds(
    double amount,
    String method,
    String details,
  ) async {
    if (amount <= 0 || amount > bycBalance) {
      _errorMessage = 'Invalid amount or insufficient balance';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final api = await WalletApi.create();
      await api.requestWithdrawal(
        amount: amount,
        memo: 'Withdrawal via $method',
        destination: {
          'method': method,
          'details': details,
        },
      );

      final userId = _wallet?.userId;
      if (userId != null) {
        await _loadWallet(userId);
      }
      await loadTransactions(refresh: true);

      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t request withdrawal. Please try again.',
      );
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Process purchase — not supported as a local mock; use listing/checkout flows.
  Future<bool> processPurchase({
    required String itemId,
    required String itemTitle,
    required double amount,
    String? sellerId,
    String? sellerName,
  }) async {
    _errorMessage =
        'Purchases must go through the listing checkout — no local wallet simulation.';
    notifyListeners();
    return false;
  }

  // Convert BYC to other currency (for display)
  double convertBYC(double bycAmount, String toCurrency) {
    final rate = _exchangeRates[toCurrency.toUpperCase()] ?? 1.0;
    return bycAmount * rate;
  }

  // Convert from other currency to BYC
  double convertToBYC(double amount, String fromCurrency) {
    final rate = _exchangeRates[fromCurrency.toUpperCase()] ?? 1.0;
    return amount / rate;
  }

  // Get recommended payment gateway for currency
  PaymentGateway? getRecommendedPaymentGateway(String currency) {
    return _paymentManager?.getRecommendedGateway(currency);
  }

  /// Returns gateways for the selected currency only.
  /// NGN, GHS, KES, ZAR → Paystack (NGN) + Flutterwave
  /// USD and other → Stripe + PayPal only
  List<PaymentGateway> getPaymentGatewaysForCurrency(String currency) {
    final pm = _paymentManager;
    if (pm == null) return [];
    return pm.getGatewaysForCurrency(currency.toUpperCase());
  }

  /// Supported currencies for funding. Always includes NGN, GHS, KES, ZAR, USD
  /// so users can select currency first; payment gateways are then filtered by selection.
  List<String> getSupportedFiatCurrencies() {
    const fallback = ['NGN', 'GHS', 'KES', 'ZAR', 'USD'];
    final fromGateways = _paymentManager?.getAllSupportedCurrencies() ?? [];
    final merged = {...fromGateways, ...fallback};
    return merged.toList()..sort();
  }

  // Calculate BYC amount for fiat funding
  double calculateBYCForFiat(double fiatAmount, String currency) {
    return convertToBYC(fiatAmount, currency);
  }

  // Calculate fiat amount needed for desired BYC
  double calculateFiatForBYC(double bycAmount, String currency) {
    final rate = _exchangeRates[currency.toUpperCase()] ?? 1.0;
    return bycAmount * rate;
  }

  /// Apply rates from API: 1 BYC = [rate] fiat per currency code.
  void applyBcyToFiatRates(Map<String, double> rates) {
    if (rates.isEmpty) return;
    _exchangeRates = {..._exchangeRates, ...rates};
    _bycToUsdRate = rates['USD'] ?? _bycToUsdRate;
    notifyListeners();
  }

  // Update exchange rates from /v1/wallet/rates
  Future<void> updateExchangeRates() async {
    try {
      final api = await WalletApi.create();
      final items = await api.getRates(forceRefresh: true);
      final parsed = <String, double>{};
      for (final raw in items) {
        if (raw is! Map) continue;
        final base = (raw['base'] as String?)?.toUpperCase() ?? 'BYC';
        final quote = (raw['quote'] as String?)?.toUpperCase() ?? '';
        if (base != 'BYC' || quote.isEmpty) continue;
        final rateRaw = raw['rate'];
        final rate = rateRaw is num
            ? rateRaw.toDouble()
            : double.tryParse(rateRaw?.toString() ?? '') ?? 0;
        if (rate > 0) parsed[quote] = rate;
      }
      if (parsed.isNotEmpty) {
        applyBcyToFiatRates(parsed);
        return;
      }
    } catch (_) {
      // Keep last known rates; do not invent fake FX.
    }
  }

  // Set transaction filters
  void setTransactionTypeFilter(TransactionType? type) {
    _selectedType = type;
    _applyFilters();
    notifyListeners();
  }

  void setTransactionStatusFilter(TransactionStatus? status) {
    _selectedStatus = status;
    _applyFilters();
    notifyListeners();
  }

  void setDateRangeFilter(DateTime? startDate, DateTime? endDate) {
    _startDate = startDate;
    _endDate = endDate;
    _applyFilters();
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    _applyFilters();
    notifyListeners();
  }

  // Clear filters
  void clearFilters() {
    _selectedType = null;
    _selectedStatus = null;
    _startDate = null;
    _endDate = null;
    _sortBy = 'newest';
    _applyFilters();
    notifyListeners();
  }

  // Apply filters
  void _applyFilters() {
    _filteredTransactions = List.from(_transactions);

    // Type filter
    if (_selectedType != null) {
      _filteredTransactions = _filteredTransactions
          .where((t) => t.type == _selectedType)
          .toList();
    }

    // Status filter
    if (_selectedStatus != null) {
      _filteredTransactions = _filteredTransactions
          .where((t) => t.status == _selectedStatus)
          .toList();
    }

    // Date range filter
    if (_startDate != null || _endDate != null) {
      _filteredTransactions = _filteredTransactions.where((t) {
        if (_startDate != null && t.createdAt.isBefore(_startDate!))
          return false;
        if (_endDate != null && t.createdAt.isAfter(_endDate!)) return false;
        return true;
      }).toList();
    }

    // Sorting
    _filteredTransactions.sort((a, b) {
      switch (_sortBy) {
        case 'oldest':
          return a.createdAt.compareTo(b.createdAt);
        case 'amount_high':
          return b.amount.compareTo(a.amount);
        case 'amount_low':
          return a.amount.compareTo(b.amount);
        case 'newest':
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
  }

  // Get transaction by ID
  BYCTransaction? getTransactionById(String transactionId) {
    try {
      return _transactions.firstWhere((t) => t.id == transactionId);
    } catch (e) {
      return null;
    }
  }

  // Get recent transactions
  List<BYCTransaction> getRecentTransactions({int limit = 5}) {
    final recent = List.from(_transactions);
    recent.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return recent.take(limit).toList().cast<BYCTransaction>();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Refresh wallet data
  Future<void> refreshWallet() async {
    if (_wallet == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _loadWallet(_wallet!.userId);
      await loadTransactions(refresh: true);
      await updateExchangeRates();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = NetworkErrorMessage.from(e, fallback: 'Couldn\'t complete that. Please try again.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
