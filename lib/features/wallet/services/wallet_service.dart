import 'package:bybata/core/api/api_client.dart';
import 'package:bybata/core/config/env_config.dart';
import 'package:bybata/core/utils/network_error_message.dart';
import 'package:bybata/core/utils/offline_json_cache.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/wallet_models.dart';
import '../utils/promotion_error_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'wallet_api.dart';

/// Service class for managing all BYC wallet operations
class WalletService extends ChangeNotifier {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  bool get isInitialized => _currentBalance != null;
  
  // Track the current user to prevent cross-user data leakage
  String? _currentUserId;

  // Current user's wallet data
  WalletBalance? _currentBalance;
  List<WalletTransaction> _transactions = [];
  List<PaymentMethod> _paymentMethods = [];
  List<WalletContact> _contacts = [];
  List<WalletPromotion> _promotions = [];
  List<ConversionRate> _conversionRates = [];
  List<PromotionPlan> _promotionPlans = [];
  List<Map<String, dynamic>> _scheduledAds = [];
  Map<String, dynamic>? _boostConfig;
  
  bool _isLoading = false;
  String? _error;

  // Getters
  WalletBalance? get currentBalance => _currentBalance;
  List<WalletTransaction> get transactions => _transactions;
  List<PaymentMethod> get paymentMethods => _paymentMethods;
  List<WalletContact> get contacts => _contacts;
  List<WalletPromotion> get promotions => _promotions;
  List<ConversionRate> get conversionRates => _conversionRates;
  List<PromotionPlan> get promotionPlans => _promotionPlans;
  List<Map<String, dynamic>> get scheduledAds => _scheduledAds;
  Map<String, dynamic>? get boostConfig => _boostConfig;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Balance formatted for display
  String get formattedBalance => _formatCurrency(_currentBalance?.totalBalance ?? 0.0);
  String get formattedAvailableBalance => _formatCurrency(_currentBalance?.availableBalance ?? 0.0);
  String get formattedPendingBalance => _formatCurrency(_currentBalance?.pendingBalance ?? 0.0);

  /// Initialize wallet data for the current user
  Future<void> initializeWallet(String userId) async {
    print('🔵 WalletService: Initializing wallet for userId=$userId, current userId=$_currentUserId');
    
    // Clear previous user's data if switching users
    if (_currentUserId != null && _currentUserId != userId) {
      print('⚠️ WalletService: User switched from $_currentUserId to $userId - clearing old data');
      _clearAllData();
    }
    
    _currentUserId = userId;
    _setLoading(true);
    _clearError();

    // Offline-first: show last known balance/transactions immediately.
    await _hydrateWalletFromDisk(userId);

    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      // Balance
      final balRes = await api.get('/v1/wallet/balance');
      final b = balRes.data;
      
      // Helper function to safely parse balance (handles both string and num from API)
      double parseBalance(dynamic value) {
        if (value == null) return 0.0;
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      }
      
      final balance = parseBalance(b['balance']);
      final available = parseBalance(b['available']) + parseBalance(b['availableBalance']);
      
      print('💰 WalletService: Loaded balance for user $userId: $balance BYC');
      print('   API Response: $b');
      
      _currentBalance = WalletBalance(
        userId: userId,
        totalBalance: balance,
        availableBalance: available > 0 ? available : balance,
        pendingBalance: parseBalance(b['pending']),
        promotionalBalance: parseBalance(b['promotionalBalance']),
        lastUpdated: DateTime.now(),
        history: const [],
      );
      // Transactions and promotions — API only (no mock money/history).
      await _loadTransactionsFromApi(api);
      await _loadPromotionPlansFromApi(api);
      await _loadScheduledAdsFromApi(api);
      await _loadConversionRatesFromApi(api);
      _paymentMethods = [];
      _contacts = [];
      _promotions = [];
      
      _clearError();
      notifyListeners();
      unawaited(_persistWalletToDisk(userId));
    } catch (e) {
      if (_currentBalance != null) {
        // Keep cached wallet visible offline.
        _clearError();
        notifyListeners();
      } else {
        _setError(NetworkErrorMessage.from(
          e,
          fallback: 'Couldn\'t load your wallet. Please try again.',
        ));
      }
    } finally {
      _setLoading(false);
    }
  }

  static const _walletBox = 'wallet_cache';

  Future<void> _hydrateWalletFromDisk(String userId) async {
    try {
      final balanceMap =
          await OfflineJsonCache.getMap(_walletBox, userId, 'balance');
      if (balanceMap != null) {
        _currentBalance = WalletBalance.fromJson(balanceMap);
      }
      final txMaps =
          await OfflineJsonCache.getList(_walletBox, userId, 'transactions');
      if (txMaps.isNotEmpty) {
        _transactions = txMaps.map(WalletTransaction.fromJson).toList();
      }
      if (_currentBalance != null || _transactions.isNotEmpty) {
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _persistWalletToDisk(String userId) async {
    try {
      if (_currentBalance != null) {
        await OfflineJsonCache.putMap(
          _walletBox,
          userId,
          'balance',
          _currentBalance!.toJson(),
        );
      }
      final clipped = _transactions.length > 100
          ? _transactions.take(100).toList()
          : _transactions;
      await OfflineJsonCache.putList(
        _walletBox,
        userId,
        'transactions',
        clipped.map((t) => t.toJson()).toList(),
      );
    } catch (_) {}
  }

  /// Direct local funding is disabled — use gateway checkout screens.
  Future<WalletTransaction?> fundWallet({
    required double amount,
    required String paymentMethodId,
    String? description,
  }) async {
    _setError(
      'Use Fund Wallet with Paystack, Stripe, PayPal, or Flutterwave. Local funding simulation is disabled.',
    );
    notifyListeners();
    return null;
  }

  /// Send BYC via the real transfer API (no local balance simulation).
  Future<WalletTransaction?> sendBYC({
    required String recipientId,
    String recipientName = 'Recipient',
    required double amount,
    String? description,
    String? note,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }
      if (recipientId.trim().isEmpty) {
        throw Exception('Recipient is required');
      }
      if (amount > (_currentBalance?.availableBalance ?? 0)) {
        throw Exception('Insufficient balance');
      }

      final api = await WalletApi.create();
      final to = recipientId.trim();
      final looksLikeEmail = to.contains('@');
      await api.transfer(
        toUserId: looksLikeEmail ? null : to,
        toEmail: looksLikeEmail ? to : null,
        amountByc: amount,
        memo: note ?? description ?? 'Sent BYC to $recipientName',
      );

      final userId = _currentBalance?.userId;
      if (userId != null) {
        await initializeWallet(userId);
      }
      _updateContact(to, recipientName, amount, true);
      return _transactions.isNotEmpty ? _transactions.first : null;
    } catch (e) {
      _setError(NetworkErrorMessage.from(
        e,
        fallback: 'Couldn\'t send BYC. Please try again.',
      ));
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Create a promotion for boosting content visibility
  Future<WalletPromotion?> createPromotion({
    required PromotionType type,
    required String title,
    required String description,
    required double bycCost,
    required Duration duration,
    String? targetId,
    String? targetType,
    List<String> targetAudience = const [],
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Validate cost and balance
      if (bycCost <= 0) {
        throw Exception('Promotion cost must be greater than 0');
      }

      if (bycCost > (_currentBalance?.availableBalance ?? 0)) {
        throw Exception('Insufficient balance for promotion');
      }

      // Create promotion
      final promotion = WalletPromotion(
        id: _generatePromotionId(),
        userId: _currentBalance!.userId,
        type: type,
        title: title,
        description: description,
        bycCost: bycCost,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(duration),
        targetId: targetId,
        targetType: targetType,
        targetAudience: targetAudience,
      );

      // Create transaction for promotion cost
      final transaction = WalletTransaction(
        id: _generateTransactionId(),
        userId: _currentBalance!.userId,
        type: TransactionType.promotion,
        amount: bycCost,
        fee: 0.0,
        netAmount: bycCost,
        status: TransactionStatus.completed,
        description: 'Promotion: $title',
        timestamp: DateTime.now(),
        promotionId: promotion.id,
        metadata: {
          'promotion': promotion.toJson(),
        },
      );

      // Add promotion and transaction
      _promotions.insert(0, promotion);
      _transactions.insert(0, transaction);

      // Update balance
      _currentBalance = _currentBalance!.copyWith(
        totalBalance: _currentBalance!.totalBalance - bycCost,
        availableBalance: _currentBalance!.availableBalance - bycCost,
        promotionalBalance: _currentBalance!.promotionalBalance + bycCost,
        lastUpdated: DateTime.now(),
      );

      notifyListeners();
      return promotion;

    } catch (e) {
      _setError('Failed to create promotion: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get transaction history with optional filtering
  List<WalletTransaction> getTransactionHistory({
    TransactionType? type,
    TransactionStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
  }) {
    var filtered = _transactions.where((transaction) {
      if (type != null && transaction.type != type) return false;
      if (status != null && transaction.status != status) return false;
      if (fromDate != null && transaction.timestamp.isBefore(fromDate)) return false;
      if (toDate != null && transaction.timestamp.isAfter(toDate)) return false;
      return true;
    }).toList();

    // Sort by timestamp (newest first)
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Apply limit if specified
    if (limit != null && filtered.length > limit) {
      filtered = filtered.take(limit).toList();
    }

    return filtered;
  }

  /// Get recent transactions (last 10)
  List<WalletTransaction> get recentTransactions => 
      getTransactionHistory(limit: 10);
  
  /// Get all transactions
  List<WalletTransaction> get allTransactions => _transactions;

  // Aliases for backward compatibility in tests
  List<PaymentMethod> get availablePaymentMethods => _paymentMethods;
  List<WalletPromotion> get availablePromotions => _promotions;

  // Public error setter for tests
  void setError(String message) => _setError(message);

  /// After a real gateway/API mutation, refresh from server (no optimistic fake money).
  Future<void> refreshFromServer() async {
    final userId = _currentBalance?.userId ?? _currentUserId;
    if (userId == null) return;
    await initializeWallet(userId);
  }

  @Deprecated('Use refreshFromServer after verify — does not invent local credits')
  Future<void> recordExternalFunding({
    required double bycAmount,
    String description = 'Wallet funding',
  }) async {
    await refreshFromServer();
  }

  @Deprecated('Use refreshFromServer after transfer — does not invent local debits')
  Future<void> recordExternalSend({
    required String recipientEmail,
    required double bycAmount,
    String? memo,
  }) async {
    await refreshFromServer();
  }

  Future<void> _loadConversionRatesFromApi(ApiClient api) async {
    try {
      final res = await api.get('/v1/wallet/rates');
      final items = (res.data['items'] as List?) ?? (res.data as List?) ?? [];
      final rates = <ConversionRate>[];
      for (final raw in items) {
        if (raw is! Map) continue;
        final base = (raw['base'] as String?)?.toLowerCase() ?? 'byc';
        final quote = (raw['quote'] as String?)?.toLowerCase() ?? '';
        final rateRaw = raw['rate'];
        final rate = rateRaw is num
            ? rateRaw.toDouble()
            : double.tryParse(rateRaw?.toString() ?? '') ?? 0;
        if (rate <= 0 || quote.isEmpty) continue;
        CurrencyType? from;
        CurrencyType? to;
        try {
          from = CurrencyType.values.firstWhere((e) => e.name == base);
        } catch (_) {
          from = null;
        }
        try {
          to = CurrencyType.values.firstWhere((e) => e.name == quote);
        } catch (_) {
          to = null;
        }
        if (from == null || to == null) continue;
        rates.add(ConversionRate(
          fromCurrency: from,
          toCurrency: to,
          rate: rate,
          buyRate: rate,
          sellRate: rate,
          lastUpdated: DateTime.now(),
        ));
      }
      _conversionRates = rates;
    } catch (_) {
      _conversionRates = [];
    }
  }

  Future<void> _loadTransactionsFromApi(ApiClient api) async {
    try {
      final res = await api.get('/v1/wallet/transactions', queryParameters: { 'page': '1', 'size': '100' });
      final items = (res.data['items'] as List?) ?? (res.data as List?) ?? [];
      _transactions = items.map<WalletTransaction>((t) {
        final typeStr = (t['type'] as String?) ?? '';
        final statusStr = (t['status'] as String?) ?? '';
        TransactionType type;
        switch (typeStr.toUpperCase()) {
          case 'FUND': type = TransactionType.fund; break;
          case 'SEND': type = TransactionType.send; break;
          case 'RECEIVE': type = TransactionType.receive; break;
          case 'PROMOTION': type = TransactionType.promotion; break;
          case 'ADVERT': type = TransactionType.advert; break;
          case 'REFUND': type = TransactionType.refund; break;
          case 'BONUS': type = TransactionType.bonus; break;
          case 'CASHBACK': type = TransactionType.cashback; break;
          default: type = TransactionType.fund; break;
        }
        TransactionStatus status;
        switch (statusStr.toUpperCase()) {
          case 'SUCCESS': status = TransactionStatus.completed; break;
          case 'PENDING': status = TransactionStatus.pending; break;
          case 'FAILED': status = TransactionStatus.failed; break;
          default: status = TransactionStatus.processing; break;
        }
        final createdAt = t['createdAt'] ?? t['timestamp'];
        final memo = (t['memo'] as String?) ?? (t['description'] as String?) ?? (t['referenceType'] != null ? '${t['referenceType']} ${t['referenceId'] ?? ''}'.trim() : 'Wallet transaction');
        final rawAmount = t['amount'];
        double amount;
        if (rawAmount is num) amount = rawAmount.toDouble();
        else if (rawAmount is String) amount = double.tryParse(rawAmount) ?? 0.0;
        else amount = 0.0;
        return WalletTransaction(
          id: (t['id']?.toString() ?? _generateTransactionId()),
          userId: (t['userId']?.toString() ?? _currentBalance?.userId ?? 'current_user'),
          type: type,
          amount: amount,
          fee: 0.0,
          netAmount: amount,
          status: status,
          description: memo,
          timestamp: createdAt is String ? DateTime.parse(createdAt) : (createdAt is DateTime ? createdAt : DateTime.now()),
          recipientId: t['recipientId']?.toString(),
          recipientName: (t['user']?['profile']?['displayName'] as String?) ?? t['recipientName']?.toString(),
          senderId: t['senderId']?.toString(),
          senderName: t['senderName']?.toString(),
          referenceId: t['referenceId']?.toString(),
          metadata: Map<String, dynamic>.from(t['metadata'] ?? {}),
          paymentMethodId: null,
          promotionId: t['promotionId']?.toString(),
          transactionHash: t['transactionHash']?.toString(),
          note: null,
        );
      }).toList();
    } catch (e) {
      // Fallback: keep existing list; surface error for UI as needed
      _setError('Failed to fetch transactions: $e');
    }
  }

  Future<void> _loadPromotionPlansFromApi(ApiClient api) async {
    try {
      final res = await api.get('/v1/wallet/promotions');
      final items = (res.data as List?) ?? [];
      _promotionPlans = items
          .map((item) => PromotionPlan.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _promotionPlans = [];
    }
  }

  Future<void> _loadScheduledAdsFromApi(ApiClient api) async {
    try {
      final res = await api.get('/v1/wallet/ads/scheduled');
      final items = (res.data as List?) ?? [];
      _scheduledAds = items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (_) {
      _scheduledAds = [];
    }
  }

  Future<void> refreshPromotionData() async {
    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      await _loadPromotionPlansFromApi(api);
      await _loadScheduledAdsFromApi(api);
      await _loadBoostConfigFromApi(api);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadBoostConfigFromApi(ApiClient api) async {
    try {
      final res = await api.get('/v1/wallet/boost-config');
      _boostConfig = Map<String, dynamic>.from(res.data as Map);
    } catch (_) {
      _boostConfig = null;
    }
  }

  Future<Map<String, dynamic>?> fetchBoostConfig() async {
    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      final res = await api.get('/v1/wallet/boost-config');
      _boostConfig = Map<String, dynamic>.from(res.data as Map);
      notifyListeners();
      return _boostConfig;
    } catch (e) {
      _setError('Failed to load boost config: $e');
      return null;
    }
  }

  /// Try to purchase default boost for a trade. Returns true if successful.
  /// Sets error message on failure (e.g. insufficient funds, no config).
  Future<bool> tryPurchaseDefaultBoostForTrade(String tradeId, String title) async {
    final config = await fetchBoostConfig();
    if (config == null) {
      _setError('Boost configuration unavailable');
      return false;
    }
    final types = (config['boostTypes'] as List?) ?? [];
    final configs = (config['configs'] as List?) ?? [];
    if (types.isEmpty || configs.isEmpty) {
      _setError('Boost options not configured');
      return false;
    }
    final typeId = types.first['id']?.toString() ?? '';
    final selectedConfig = configs.firstWhere(
      (c) => c['boostTypeId']?.toString() == typeId,
      orElse: () => configs.first,
    );
    final days = (selectedConfig['minDays'] as int?) ?? 1;
    final placementKeys = (selectedConfig['placementKeys'] as List?)?.map((e) => e.toString()).toList();
    const placementKey = 'trade_feed';
    final cost = _boostCostFromConfig(selectedConfig, days);
    final balance = _currentBalance?.availableBalance ?? 0.0;
    if (cost <= 0 || balance < cost) {
      _setError('Insufficient balance. Need ${cost.toStringAsFixed(0)} BYC, have ${balance.toStringAsFixed(0)} BYC.');
      return false;
    }
    return purchaseBoost(
      referenceType: 'trade',
      referenceId: tradeId,
      boostTypeId: typeId,
      days: days,
      placementKey: placementKey,
    );
  }

  double dailyRateForPlacementKey(
    String key,
    Map<String, double> adPricing,
  ) {
    final k = key.toLowerCase();
    if (k.contains('trade')) return adPricing['tradeBycPerDay'] ?? 2.5;
    if (k.contains('gift')) return adPricing['giftBycPerDay'] ?? 2;
    if (k.contains('donation') || k.contains('campaign')) {
      return adPricing['donationBycPerDay'] ?? 2;
    }
    return adPricing['normalBycPerDay'] ?? 3;
  }

  double computeBoostPurchaseTotal({
    required Map<String, dynamic> config,
    required int dayCount,
    required Iterable<String> placementKeys,
    required Map<String, double> adPricing,
  }) {
    if (dayCount <= 0 || placementKeys.isEmpty) return 0;
    final model = (config['pricingModel']?.toString() ?? 'FIXED').toUpperCase();
    if (model == 'DAILY') {
      var perDay = 0.0;
      for (final key in placementKeys) {
        perDay += dailyRateForPlacementKey(key, adPricing);
      }
      return perDay * dayCount;
    }
    final base = _boostCostFromConfig(config, dayCount);
    return base * placementKeys.length;
  }

  double _boostCostFromConfig(Map<String, dynamic> config, int days) {
    final model = (config['pricingModel']?.toString() ?? 'FIXED').toUpperCase();
    if (model == 'DAILY') {
      final daily = _toDouble(config['dailyCostBYC']);
      return daily * days;
    }
    if (model == 'TIERED') {
      final tiers = config['tiers'];
      if (tiers is List) {
        for (final tier in tiers) {
          final map = Map<String, dynamic>.from(tier as Map);
          final min = (map['minDays'] as int?) ?? (map['days'] as int?) ?? 1;
          final max = (map['maxDays'] as int?) ?? min;
          if (days >= min && days <= max) return _toDouble(map['cost']);
        }
      }
    }
    return _toDouble(config['baseCostBYC']);
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  Future<bool> purchaseBoost({
    required String referenceType,
    required String referenceId,
    required String boostTypeId,
    int? days,
    List<String>? boostDates,
    List<String>? placementKeys,
    String? placementKey,
    String? destinationUrl,
    String? idempotencyKey,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      await api.post('/v1/wallet/boosts/purchase', data: {
        'referenceType': referenceType,
        'referenceId': referenceId,
        'boostTypeId': boostTypeId,
        if (boostDates != null && boostDates.isNotEmpty)
          'boostDates': boostDates
        else if (days != null)
          'days': days,
        if (placementKeys != null && placementKeys.isNotEmpty)
          'placementKeys': placementKeys
        else if (placementKey != null && placementKey.isNotEmpty)
          'placementKey': placementKey,
        if (destinationUrl != null && destinationUrl.isNotEmpty)
          'destinationUrl': destinationUrl,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      });
      await _loadTransactionsFromApi(api);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to purchase boost: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> purchasePromotion({
    required PromotionPlan plan,
    required String referenceType,
    required String referenceId,
    String? idempotencyKey,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      await api.post('/v1/wallet/promotions/purchase', data: {
        'promotionSlug': plan.slug,
        'referenceType': referenceType,
        'referenceId': referenceId,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      });
      await _loadTransactionsFromApi(api);
      if (_currentBalance != null) {
        _currentBalance = _currentBalance!.copyWith(
          totalBalance: (_currentBalance!.totalBalance - plan.amountByc).clamp(0.0, double.infinity),
          availableBalance: (_currentBalance!.availableBalance - plan.amountByc).clamp(0.0, double.infinity),
          lastUpdated: DateTime.now(),
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to purchase promotion: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> scheduleAd({
    required String title,
    String? description,
    String mediaType = 'IMAGE',
    List<String>? mediaKeys,
    String? videoKey,
    String? placementKey,
    List<String>? placementKeys,
    required DateTime scheduledStart,
    DateTime? scheduledEnd,
    required double amount,
    required String destinationUrl,
    String? idempotencyKey,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final keys = placementKeys ??
          (placementKey != null ? [placementKey] : <String>[]);
      if (keys.isEmpty) {
        _setError('Select at least one placement');
        return false;
      }
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      await api.post('/v1/wallet/ads/schedule', data: {
        'title': title,
        if (description != null) 'description': description,
        'mediaType': mediaType,
        if (mediaKeys != null) 'mediaKeys': mediaKeys,
        if (videoKey != null) 'videoKey': videoKey,
        'placementKey': keys.first,
        'placementKeys': keys,
        'scheduledStart': scheduledStart.toIso8601String(),
        if (scheduledEnd != null) 'scheduledEnd': scheduledEnd.toIso8601String(),
        'amount': amount,
        'destinationUrl': destinationUrl,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      });
      await _loadTransactionsFromApi(api);
      await _loadScheduledAdsFromApi(api);
      if (_currentBalance != null) {
        _currentBalance = _currentBalance!.copyWith(
          totalBalance: (_currentBalance!.totalBalance - amount).clamp(0.0, double.infinity),
          availableBalance: (_currentBalance!.availableBalance - amount).clamp(0.0, double.infinity),
          lastUpdated: DateTime.now(),
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      final raw = PromotionErrorHandler.extractBackendMessage(e);
      _setError(
        PromotionErrorHandler.parseErrorMessage(raw),
      );
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateAd({
    required String adScheduleId,
    String? title,
    String? description,
    String? mediaType,
    List<String>? mediaKeys,
    String? videoKey,
    List<String>? placementKeys,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? destinationUrl,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      await api.patch('/v1/wallet/ads/$adScheduleId', data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (mediaType != null) 'mediaType': mediaType,
        if (mediaKeys != null) 'mediaKeys': mediaKeys,
        if (videoKey != null) 'videoKey': videoKey,
        if (placementKeys != null) 'placementKeys': placementKeys,
        if (scheduledStart != null)
          'scheduledStart': scheduledStart.toIso8601String(),
        if (scheduledEnd != null)
          'scheduledEnd': scheduledEnd.toIso8601String(),
        if (destinationUrl != null) 'destinationUrl': destinationUrl,
      });
      await _loadScheduledAdsFromApi(api);
      notifyListeners();
      return true;
    } catch (e) {
      final raw = PromotionErrorHandler.extractBackendMessage(e);
      _setError(PromotionErrorHandler.parseErrorMessage(raw));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateAdStatus({
    required String adScheduleId,
    required String status,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      await api.post('/v1/wallet/ads/$adScheduleId/status', data: {
        'status': status,
      });
      await _loadScheduledAdsFromApi(api);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update ad status: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> getAdPerformance(String adScheduleId) async {
    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      final res = await api.get('/v1/wallet/ads/$adScheduleId/performance');
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      _setError('Failed to load ad performance: $e');
      return null;
    }
  }

  // Refresh balance from API (fetch real user-specific data)
  /// Refresh transactions from API (e.g. when opening Transaction History)
  Future<void> refreshTransactions() async {
    if (_currentUserId == null) return;
    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      await _loadTransactionsFromApi(api);
      _clearError();
    } catch (e) {
      _setError('Failed to refresh transactions: $e');
    }
    notifyListeners();
  }

  Future<void> refreshBalance() async {
    if (_currentUserId == null) {
      print('⚠️ WalletService.refreshBalance: No current user ID');
      return;
    }
    
    _setLoading(true);
    print('🔄 WalletService: Refreshing balance for user $_currentUserId');
    
    try {
      const storage = FlutterSecureStorage();
      final baseUrl = await EnvConfig.getBaseUrl();
      final api = ApiClient(baseUrl, storage);
      
      final balRes = await api.get('/v1/wallet/balance');
      final b = balRes.data;
      
      // Helper function to safely parse balance (handles both string and num from API)
      double parseBalance(dynamic value) {
        if (value == null) return 0.0;
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      }
      
      final balance = parseBalance(b['balance']);
      final available = parseBalance(b['available']) + parseBalance(b['availableBalance']);
      
      print('💰 WalletService: Refreshed balance for user $_currentUserId: $balance BYC');
      
      _currentBalance = WalletBalance(
        userId: _currentUserId!,
        totalBalance: balance,
        availableBalance: available > 0 ? available : balance,
        pendingBalance: parseBalance(b['pending']),
        promotionalBalance: parseBalance(b['promotionalBalance']),
        lastUpdated: DateTime.now(),
        history: const [],
      );
      
      notifyListeners();
    } catch (e) {
      print('❌ WalletService: Failed to refresh balance - $e');
      _setError('Failed to refresh balance: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshConversionRates() async {
    _setLoading(true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      _conversionRates = _conversionRates.map((r) => ConversionRate(
            fromCurrency: r.fromCurrency,
            toCurrency: r.toCurrency,
            rate: r.rate,
            buyRate: r.buyRate,
            sellRate: r.sellRate,
            lastUpdated: DateTime.now(),
            change24h: r.change24h,
            changePercent24h: r.changePercent24h,
            high24h: r.high24h,
            low24h: r.low24h,
          )).toList();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> activatePromotion(WalletPromotion promotion) async {
    if (_currentBalance == null) return false;
    final cost = promotion.bycCost;
    if (cost > _currentBalance!.availableBalance) {
      throw Exception('Insufficient balance for promotion');
    }
    _currentBalance = _currentBalance!.copyWith(
      totalBalance: _currentBalance!.totalBalance - cost,
      availableBalance: _currentBalance!.availableBalance - cost,
      promotionalBalance: _currentBalance!.promotionalBalance + cost,
      lastUpdated: DateTime.now(),
    );
    notifyListeners();
    return true;
  }

  /// Add a new payment method
  Future<PaymentMethod?> addPaymentMethod({
    required PaymentMethodType type,
    required String name,
    required String displayName,
    String? lastFour,
    String? expiryDate,
    String? brand,
    bool isDefault = false,
    Map<String, dynamic> metadata = const {},
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final paymentMethod = PaymentMethod(
        id: _generatePaymentMethodId(),
        userId: _currentBalance!.userId,
        type: type,
        name: name,
        displayName: displayName,
        lastFour: lastFour,
        expiryDate: expiryDate,
        brand: brand,
        isDefault: isDefault,
        createdAt: DateTime.now(),
        metadata: metadata,
      );

      // If this is set as default, unset other defaults
      if (isDefault) {
        _paymentMethods = _paymentMethods.map((pm) => 
          PaymentMethod(
            id: pm.id,
            userId: pm.userId,
            type: pm.type,
            name: pm.name,
            displayName: pm.displayName,
            lastFour: pm.lastFour,
            expiryDate: pm.expiryDate,
            brand: pm.brand,
            isDefault: false, // Unset default
            isActive: pm.isActive,
            createdAt: pm.createdAt,
            lastUsed: pm.lastUsed,
            metadata: pm.metadata,
          )
        ).toList();
      }

      _paymentMethods.add(paymentMethod);
      notifyListeners();
      return paymentMethod;

    } catch (e) {
      _setError('Failed to add payment method: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Update contact after transaction
  void _updateContact(String contactUserId, String contactName, double amount, bool isSent) {
    final existingContactIndex = _contacts.indexWhere((c) => c.contactUserId == contactUserId);
    
    if (existingContactIndex != -1) {
      // Update existing contact
      final existing = _contacts[existingContactIndex];
      _contacts[existingContactIndex] = WalletContact(
        id: existing.id,
        userId: existing.userId,
        contactUserId: existing.contactUserId,
        contactName: contactName, // Update name in case it changed
        contactEmail: existing.contactEmail,
        contactPhone: existing.contactPhone,
        contactAvatar: existing.contactAvatar,
        transactionCount: existing.transactionCount + 1,
        totalSent: existing.totalSent + (isSent ? amount : 0),
        totalReceived: existing.totalReceived + (!isSent ? amount : 0),
        lastTransaction: DateTime.now(),
        createdAt: existing.createdAt,
        isFavorite: existing.isFavorite,
      );
    } else {
      // Add new contact
      _contacts.add(WalletContact(
        id: _generateContactId(),
        userId: _currentBalance!.userId,
        contactUserId: contactUserId,
        contactName: contactName,
        contactEmail: contactUserId.contains('@') ? contactUserId : '',
        transactionCount: 1,
        totalSent: isSent ? amount : 0,
        totalReceived: !isSent ? amount : 0,
        lastTransaction: DateTime.now(),
        createdAt: DateTime.now(),
      ));
    }
  }

  /// Format currency amount for display
  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} BYC';
  }

  /// Helper methods for loading states
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = NetworkErrorMessage.sanitize(error);
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  /// ID generators
  String _generateTransactionId() => 'txn_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  String _generatePromotionId() => 'promo_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  String _generatePaymentMethodId() => 'pm_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  String _generateContactId() => 'contact_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

  /// Clear all wallet data (used when switching users)
  void _clearAllData() {
    print('🧹 WalletService: Clearing all wallet data for user switch');
    _currentBalance = null;
    _transactions = [];
    _paymentMethods = [];
    _contacts = [];
    _promotions = [];
    _conversionRates = [];
    _error = null;
    notifyListeners();
    print('✅ WalletService: All data cleared');
  }
}
