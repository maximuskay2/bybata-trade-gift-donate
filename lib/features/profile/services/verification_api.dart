import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/env_config.dart';
import '../models/user_profile.dart';

class VerificationApi {
  late final ApiClient _api;

  VerificationApi._(this._api);

  static Future<VerificationApi> create() async {
    final baseUrl = await EnvConfig.getBaseUrl();
    final storage = const FlutterSecureStorage();
    final api = ApiClient(baseUrl, storage);
    return VerificationApi._(api);
  }

  Future<void> requestEmailVerification(String email) async {
    await _api.post('/v1/auth/verify-request', data: {'email': email});
  }

  Future<void> confirmEmailVerification(String token) async {
    await _api.post('/v1/auth/verify-confirm', data: {'token': token});
  }

  Future<Map<String, dynamic>> requestPhoneVerification(String phoneNumber) async {
    final res = await _api.post('/v1/auth/phone-verify-request', data: {'phoneNumber': phoneNumber});
    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return {'success': true};
  }

  Future<void> confirmPhoneVerification(String code) async {
    await _api.post('/v1/auth/phone-verify-confirm', data: {'code': code});
  }

  Future<String> uploadVerificationDocument(String filePath, VerificationType type) async {
    final fileExtension = filePath.split('.').last.toLowerCase();
    final contentType = _getContentType(fileExtension);

    final uploadRes = await _api.post('/v1/storage/upload-url', data: {
      'domain': 'profiles',
      'contentType': contentType,
      'ext': fileExtension,
    });

    final uploadUrl = uploadRes.data['uploadUrl'] as String;
    final documentKey = uploadRes.data['key'] as String;

    final dio = Dio();
    await dio.put(
      uploadUrl,
      data: await File(filePath).readAsBytes(),
      options: Options(headers: {'Content-Type': contentType}),
    );

    return documentKey;
  }

  Future<VerificationStatus> registerVerificationDocument({
    required VerificationType type,
    required String documentKey,
    String? fileName,
  }) async {
    final res = await _api.post('/v1/users/me/verification/documents', data: {
      'type': type.toString().split('.').last,
      'documentKey': documentKey,
      if (fileName != null) 'fileName': fileName,
    });
    return verificationFromResponse(res.data['verification'] ?? res.data);
  }

  String _getContentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  static VerificationStatus verificationFromResponse(dynamic data) {
    if (data is! Map) {
      return VerificationStatus(status: VerificationStatusType.pending);
    }
    final map = Map<String, dynamic>.from(data);
    final profile = map['profile'];
    if (profile is Map) {
      final profileMap = Map<String, dynamic>.from(profile);
      final verification = profileMap['verification'];
      if (verification is Map) {
        return VerificationStatus.fromJson(Map<String, dynamic>.from(verification));
      }
      return VerificationStatus.fromApiProfile(
        verification: null,
        kycStatus: profileMap['kycStatus'] as String?,
        kycNote: profileMap['kycNote'] as String?,
        emailVerified: map['emailVerifiedAt'] != null,
        phoneVerified: profileMap['phoneVerifiedAt'] != null,
      );
    }
    if (map.containsKey('status') || map.containsKey('completedVerifications')) {
      return VerificationStatus.fromJson(map);
    }
    return VerificationStatus(status: VerificationStatusType.pending);
  }

  Future<VerificationStatus> submitVerificationDocuments({
    required String userId,
    required Map<VerificationType, String> documentKeys,
  }) async {
    final res = await _api.post(
      '/v1/users/me/verification',
      data: {
        'documents': documentKeys.map(
          (key, value) => MapEntry(key.toString().split('.').last, value),
        ),
      },
    );
    return verificationFromResponse(res.data);
  }

  Future<VerificationStatus> getVerificationStatus() async {
    final res = await _api.get('/v1/users/me/verification/status');
    return VerificationStatus.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<VerificationStatus> refreshFromMe() async {
    final res = await _api.get('/v1/users/me');
    return verificationFromResponse(res.data);
  }

  Future<List<Map<String, dynamic>>> getVerificationDocuments() async {
    final res = await _api.get('/v1/users/me/verification/documents');
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }
}
