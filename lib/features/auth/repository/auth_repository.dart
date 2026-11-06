import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/locale_hints.dart';
import '../../../core/services/signup_location_service.dart';

class AuthRepository {
  final Dio dio;
  final FlutterSecureStorage storage;
  AuthRepository(this.dio, this.storage);

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
    required String username,
    String? referralCode,
    LocaleHints? localeHints,
  }) async {
    final data = <String, dynamic>{
      'email': email,
      'password': password,
      'displayName': displayName,
      'username': username,
    };
    if (referralCode != null && referralCode.trim().isNotEmpty) {
      data['referralCode'] = referralCode.trim();
    }
    if (localeHints != null) {
      data.addAll(localeHints.toJson());
    }
    final res = await dio.post('/v1/auth/register', data: data);
    await _storeTokens(res.data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<bool> isUsernameAvailable(String username) async {
    final res = await dio.get('/v1/users/username-available', queryParameters: {
      'username': username,
    });
    final data = res.data;
    if (data is Map && data['available'] is bool) {
      return data['available'] as bool;
    }
    return false;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final location = await SignupLocationService.resolveForAuth();
    final res = await dio.post('/v1/auth/login', data: {
      'email': email,
      'password': password,
      if (location != null && location.isNotEmpty) 'location': location,
    });
    await _storeTokens(res.data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    LocaleHints? localeHints,
  }) async {
    final location = localeHints?.location ??
        await SignupLocationService.resolveForAuth();
    final res = await dio.post('/v1/auth/google', data: {
      'idToken': idToken,
      ...?localeHints?.toJson(),
      if (location != null && location.isNotEmpty) 'location': location,
    });
    await _storeTokens(res.data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> loginWithApple({
    required String identityToken,
    String? email,
    String? displayName,
    LocaleHints? localeHints,
  }) async {
    final location = localeHints?.location ??
        await SignupLocationService.resolveForAuth();
    final res = await dio.post('/v1/auth/apple', data: {
      'identityToken': identityToken,
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
      ...?localeHints?.toJson(),
      if (location != null && location.isNotEmpty) 'location': location,
    });
    await _storeTokens(res.data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> logout(String userId) async {
    try { await dio.post('/v1/auth/logout', data: { 'userId': userId }); } catch (_) {}
    await _safeDelete('access');
    await _safeDelete('refresh');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  Future<void> _storeTokens(dynamic data) async {
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (access != null) await _safeWrite('access', access);
    if (refresh != null) await _safeWrite('refresh', refresh);
    final prefs = await SharedPreferences.getInstance();
    if (access != null) await prefs.setString('auth_token', access);
    if (refresh != null) await prefs.setString('refresh_token', refresh);
  }

  Future<void> requestEmailVerification(String email) async {
    await dio.post('/v1/auth/verify-request', data: { 'email': email });
  }

  Future<void> confirmEmail(String token) async {
    await dio.post('/v1/auth/verify-confirm', data: { 'token': token });
  }

  Future<void> forgotPassword(String email) async {
    await dio.post('/v1/auth/forgot', data: { 'email': email });
  }

  Future<void> resetPassword({required String token, required String password}) async {
    await dio.post('/v1/auth/reset', data: { 'token': token, 'password': password });
  }
  Future<void> _safeWrite(String key, String value) async {
    try {
      await storage.write(key: key, value: value);
    } on PlatformException catch (_) {
      // ignore on simulator; fallback handled via SharedPreferences
    } catch (_) {}
  }

  Future<void> _safeDelete(String key) async {
    try {
      await storage.delete(key: key);
    } on PlatformException catch (_) {
      // ignore on simulator
    } catch (_) {}
  }
}
