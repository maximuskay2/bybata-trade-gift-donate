import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bybata/core/api/api_client.dart';
import 'package:bybata/core/config/env_config.dart';

class MapsConfig {
  static const MethodChannel _channel = MethodChannel('maps_config');

  static Future<void> initializeFromServer() async {
    try {
      final storage = const FlutterSecureStorage();
      final candidates = <String>[
        EnvConfig.defaultBaseUrl,
        'http://127.0.0.1:3000',
        'http://10.0.2.2:3000',
      ];
      String key = '';
      for (final base in candidates) {
        try {
          final client = ApiClient(base, storage);
          final res = await client.get('/v1/settings/maps');
          key = (res.data is Map) ? (res.data['googleMapsApiKey']?.toString() ?? '') : '';
          if (key.isNotEmpty) break;
        } catch (_) {}
      }
      if (key.isNotEmpty) {
        await _channel.invokeMethod('setApiKey', { 'apiKey': key });
      }
    } catch (_) {
    }
  }
}
