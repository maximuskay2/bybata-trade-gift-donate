import 'package:flutter/services.dart';

import 'clip_subject.dart';

/// Device crop and motion. Missing native code returns a safe fallback.
class HeroClipChannel {
  HeroClipChannel._();

  static const MethodChannel _channel = MethodChannel('bybata/hero_clip');

  /// Linear acceleration magnitude in meters per second squared. 0 if unknown.
  static Future<double> motion() async {
    try {
      final value = await _channel.invokeMethod<num>('motion');
      return value?.toDouble() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Writes a cropped mp4. Null means the original clip should be kept.
  static Future<String?> crop({
    required String source,
    required String dest,
    required NormRect rect,
  }) async {
    try {
      final path = await _channel.invokeMethod<String>('crop', {
        'source': source,
        'dest': dest,
        'left': rect.left,
        'top': rect.top,
        'width': rect.width,
        'height': rect.height,
      });
      if (path == null || path.isEmpty) return null;
      return path;
    } catch (_) {
      return null;
    }
  }
}
