import 'package:test/test.dart';
import 'package:dio/dio.dart';
import 'package:bybata/core/config/env_config.dart';

void main() {
  test('login with seeded user and fetch /users/me', () async {
    final base = await EnvConfig.getBaseUrl();
    expect(base, isNotEmpty);

    final dio = Dio(BaseOptions(baseUrl: base));

    final login = await dio.post('/v1/auth/login', data: {
      'email': 'alice@example.com',
      'password': 'password123',
    });

    final access = login.data['accessToken'] as String?;
    expect(access, isNotNull);

    final me = await dio.get('/v1/users/me', options: Options(headers: {
      'Authorization': 'Bearer $access',
    }));
    expect(me.data['email'], 'alice@example.com');
    expect(me.data['id'], isNotNull);
  });
}