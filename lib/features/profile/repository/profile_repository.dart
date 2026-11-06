import 'package:dio/dio.dart';
import '../../../core/api/api_timeouts.dart';

class ProfileRepository {
  final Dio dio;
  ProfileRepository(this.dio);

  Future<Map<String, dynamic>> me({bool light = false, bool fresh = false}) async {
    final params = <String, String>{};
    if (light) params['light'] = '1';
    if (fresh) params['fresh'] = '1';
    final res = await dio.get(
      '/v1/users/me',
      queryParameters: params.isEmpty ? null : params,
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updateMe({
    String? displayName,
    String? bio,
    String? phone,
    String? avatarKey,
    bool clearAvatar = false,
    String? preferredFiatCurrency,
    String? countryCode,
    String? timezone,
  }) async {
    final data = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (bio != null) 'bio': bio,
      if (phone != null) 'phone': phone,
      if (preferredFiatCurrency != null) 'preferredFiatCurrency': preferredFiatCurrency,
      if (countryCode != null) 'countryCode': countryCode,
      if (timezone != null) 'timezone': timezone,
    };
    if (clearAvatar) {
      data['avatarKey'] = null;
    } else if (avatarKey != null) {
      data['avatarKey'] = avatarKey;
    }
    final res = await dio.patch(
      '/v1/users/me',
      data: data,
      options: Options(receiveTimeout: ApiTimeouts.listingWrite),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await dio.post('/v1/users/me/password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<void> deleteAccount() async {
    await dio.delete('/v1/users/me');
  }

  Future<Map<String, dynamic>> updatePrivacySettings({
    bool? isProfilePublic,
    bool? showEmail,
    bool? showPhone,
    bool? showLocation,
    bool? allowDirectMessages,
  }) async {
    final res = await dio.patch(
      '/v1/users/me/privacy',
      data: {
        if (isProfilePublic != null) 'isProfilePublic': isProfilePublic,
        if (showEmail != null) 'showEmail': showEmail,
        if (showPhone != null) 'showPhone': showPhone,
        if (showLocation != null) 'showLocation': showLocation,
        if (allowDirectMessages != null) 'allowDirectMessages': allowDirectMessages,
      },
      options: Options(receiveTimeout: ApiTimeouts.listingWrite),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// GDPR-style data export request (backend emails link when ready).
  Future<Map<String, dynamic>> requestDataExport() async {
    final res = await dio.post('/v1/users/me/data-export');
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'success': true};
  }

  /// Marketing / transactional email preferences (separate from notification bell settings).
  Future<void> updateEmailPreferences({bool? marketing}) async {
    await dio.put('/v1/email/preferences', data: {
      if (marketing != null) 'marketing': marketing,
    });
  }
}