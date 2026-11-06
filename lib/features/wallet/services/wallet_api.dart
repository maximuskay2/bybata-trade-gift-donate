import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../../../core/utils/cache_store.dart';

class WalletApi {
  late final ApiClient _api;
  final _storage = const FlutterSecureStorage();

  // Simple in-memory cache for conversion rates to avoid re-fetching on every open.
  // TTL kept short; wallet balance endpoints remain uncached.
  static final CacheStore<String, List<dynamic>> _ratesCache =
      CacheStore<String, List<dynamic>>(ttl: const Duration(seconds: 60));

  WalletApi._(this._api);

  static Future<WalletApi> create() async {
    final baseUrl = await EnvConfig.getBaseUrl();
    final storage = const FlutterSecureStorage();
    final api = ApiClient(baseUrl, storage);
    return WalletApi._(api);
  }

  Future<Map<String, dynamic>> getWallet() async {
    final res = await _api.dio.get('/v1/wallet');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getTransactions({int page = 1, int size = 20}) async {
    final res = await _api.dio.get(
      '/v1/wallet/transactions',
      queryParameters: {'page': page, 'size': size},
    );
    return (res.data['items'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> searchUsers({
    required String q,
    int page = 1,
    int size = 10,
  }) async {
    final res = await _api.dio.get(
      '/v1/users/search',
      queryParameters: {'q': q, 'page': page, 'size': size},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fund({
    required double amount,
    String? memo,
    String? idempotencyKey,
  }) async {
    final res = await _api.dio.post(
      '/v1/wallet/fund',
      data: {
        'amount': amount,
        if (memo != null) 'memo': memo,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> send({
    String? toUserId,
    String? toEmail,
    required double amount,
    String? memo,
    String? idempotencyKey,
  }) async {
    final res = await _api.dio.post(
      '/v1/wallet/send',
      data: {
        if (toUserId != null) 'toUserId': toUserId,
        if (toEmail != null) 'toEmail': toEmail,
        'amount': amount,
        if (memo != null) 'memo': memo,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getRates({bool forceRefresh = false}) async {
    const cacheKey = 'wallet:rates';
    if (!forceRefresh) {
      final cached = _ratesCache.getIfFresh(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    final res = await _api.dio.get('/v1/wallet/rates');
    final items = (res.data as List?)?.toList() ?? <dynamic>[];
    _ratesCache.set(cacheKey, items);
    return items;
  }

  Future<List<dynamic>> getPromotions() async {
    final res = await _api.dio.get('/v1/wallet/promotions');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> transfer({
    String? toUserId,
    String? toEmail,
    required double amountByc,
    String? memo,
    String? idempotencyKey,
    String? verificationMethod,
    String? verificationCredential,
  }) async {
    final res = await _api.dio.post(
      '/v1/wallet/transfer',
      data: {
        if (toUserId != null) 'toUserId': toUserId,
        if (toEmail != null) 'toEmail': toEmail,
        'amountByc': amountByc,
        if (memo != null) 'memo': memo,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
        if (verificationMethod != null) 'verificationMethod': verificationMethod,
        if (verificationCredential != null) 'verificationCredential': verificationCredential,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getWithdrawals({int page = 1, int size = 20}) async {
    final res = await _api.dio.get(
      '/v1/wallet/withdrawals',
      queryParameters: {'page': page, 'size': size},
    );
    return (res.data['items'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    String? currency,
    String? memo,
    Map<String, dynamic>? destination,
    String? idempotencyKey,
    String? verificationMethod,
    String? verificationCredential,
  }) async {
    final res = await _api.dio.post(
      '/v1/wallet/withdrawals/request',
      data: {
        'amount': amount,
        if (currency != null) 'currency': currency,
        if (memo != null) 'memo': memo,
        if (destination != null) 'destination': destination,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
        if (verificationMethod != null) 'verificationMethod': verificationMethod,
        if (verificationCredential != null) 'verificationCredential': verificationCredential,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelWithdrawal(String withdrawalId, {String? reason}) async {
    final res = await _api.dio.post(
      '/v1/wallet/withdrawals/$withdrawalId/cancel',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createPaystackFunding({
    required double amount,
    String currency = 'NGN',
    String? returnUrl,
    double? amountByc,
  }) async {
    final res = await _api.dio.post(
      '/v1/wallet/fund/paystack/create',
      data: {
        'amount': amount,
        'currency': currency.toUpperCase(),
        if (returnUrl != null) 'returnUrl': returnUrl,
        if (amountByc != null && amountByc > 0) 'amountByc': amountByc,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyPaystackFunding({
    required String providerReference,
  }) async {
    final res = await _api.dio.get(
      '/v1/wallet/fund/paystack/callback',
      queryParameters: {'reference': providerReference},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyStripeFunding({
    required String sessionId,
  }) async {
    final res = await _api.dio.get(
      '/v1/wallet/fund/stripe/callback',
      queryParameters: {'session_id': sessionId},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createStripeFunding({
    required double amountUsd,
    String? returnUrl,
    double? amountByc,
  }) async {
    final res = await _api.dio.post(
      '/v1/wallet/fund/stripe/create',
      data: {
        'amountUsd': amountUsd,
        if (returnUrl != null) 'returnUrl': returnUrl,
        if (amountByc != null && amountByc > 0) 'amountByc': amountByc,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createPayPalFunding({
    required double amountUsd,
    String? returnUrl,
    double? amountByc,
  }) async {
    final res = await _api.dio.post(
      '/v1/wallet/fund/paypal/create',
      data: {
        'amountUsd': amountUsd,
        if (returnUrl != null) 'returnUrl': returnUrl,
        if (amountByc != null && amountByc > 0) 'amountByc': amountByc,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createFlutterwaveFunding({
    required double amount,
    required String currency,
    String? returnUrl,
    double? amountByc,
  }) async {
    final res = await _api.dio.post(
      '/v1/wallet/fund/flutterwave/create',
      data: {
        'amount': amount,
        'currency': currency,
        if (returnUrl != null) 'returnUrl': returnUrl,
        if (amountByc != null && amountByc > 0) 'amountByc': amountByc,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWalletAddress() async {
    final res = await _api.dio.get('/v1/wallet/address');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createReceiveQr({
    double? amount,
    String? note,
  }) async {
    final res = await _api.dio.post(
      '/v1/wallet/qr/generate',
      data: {
        if (amount != null) 'amount': amount,
        if (note != null && note.isNotEmpty) 'memo': note,
      },
    );
    return res.data as Map<String, dynamic>;
  }
  
  Future<Map<String, dynamic>> generateQRCode({
    double? amount,
    String? memo,
  }) async {
    return createReceiveQr(amount: amount, note: memo);
  }
  
  Future<Map<String, dynamic>> scanQRCode(String qrCode) async {
    final res = await _api.dio.post(
      '/v1/wallet/qr/scan',
      data: {'qrCode': qrCode},
    );
    return res.data as Map<String, dynamic>;
  }
  
  Future<Map<String, dynamic>> getSecurityStatus() async {
    final res = await _api.dio.get('/v1/wallet/security/status');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final res = await _api.dio.post(path, data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> validateQr({required String code}) async {
    final res = await _api.dio.post(
      '/v1/wallet/qr/validate',
      data: {'code': code},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _api.dio.get('/v1/users/me');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWalletAnalytics() async {
    final res = await _api.dio.get('/v1/wallet/analytics');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPublicGatewayConfigs({String mode = 'test'}) async {
    final res = await _api.dio.get(
      '/v1/public/gateways',
      queryParameters: {'mode': mode},
    );
    return (res.data['items'] as List?) ?? [];
  }

  Future<List<dynamic>> getPublicRates({bool activeOnly = true}) async {
    final res = await _api.dio.get(
      '/v1/public/rates',
      queryParameters: {'active': activeOnly ? 'true' : 'false'},
    );
    return (res.data['items'] as List?) ?? [];
  }

  /// Fetch funding packages from admin-configured endpoint (BYC amounts calculated from exchange rates).
  Future<List<dynamic>> getFundingPackages() async {
    try {
      final res = await _api.dio.get('/v1/public/funding-packages');
      final list = res.data;
      if (list is List && list.isNotEmpty) return list;
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> verifyPaypalFunding({
    required String orderId,
  }) async {
    final res = await _api.dio.get(
      '/v1/wallet/fund/paypal/callback',
      queryParameters: {'token': orderId},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyFlutterwaveFunding({
    required String transactionId,
    String? txRef,
  }) async {
    final res = await _api.dio.get(
      '/v1/wallet/fund/flutterwave/callback',
      queryParameters: {
        'transaction_id': transactionId,
        if (txRef != null) 'tx_ref': txRef,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Dio get dio => _api.dio;
}
