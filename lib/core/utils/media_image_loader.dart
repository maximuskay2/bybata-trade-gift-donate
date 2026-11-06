import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Downloads listing images with explicit timeouts and redirect handling.
class MediaImageLoader {
  MediaImageLoader._();

  static final CacheManager _cache = CacheManager(
    Config(
      'bybata_listing_images',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 400,
    ),
  );

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      followRedirects: true,
      maxRedirects: 5,
      responseType: ResponseType.bytes,
      headers: const {
        'Accept': 'image/jpeg,image/png,image/webp,image/*;q=0.8',
        'User-Agent': 'Bybata/1.0 (Flutter)',
      },
    ),
  );

  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static Future<Uint8List?> loadBytes(String url, {required String cacheKey}) async {
    final key = cacheKey.trim();
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty || key.isEmpty) return null;

    try {
      final cached = await _cache.getFileFromCache(key);
      if (cached != null && await cached.file.exists()) {
        final bytes = await cached.file.readAsBytes();
        if (_looksLikeImage(bytes)) return bytes;
        await _cache.removeFile(key);
      }
    } catch (_) {}

    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _download(trimmedUrl, key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<Uint8List?> _download(String url, String cacheKey) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(followRedirects: true, maxRedirects: 5),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) return null;

      final data = response.data;
      if (data == null || data.isEmpty) return null;

      final bytes = Uint8List.fromList(data);
      if (!_looksLikeImage(bytes)) {
        debugPrint('[MediaImageLoader] non-image response for $url (${bytes.length} bytes)');
        return null;
      }

      await _cache.putFile(
        url,
        bytes,
        key: cacheKey,
        fileExtension: _extFromUrl(url),
      );
      return bytes;
    } catch (e, st) {
      debugPrint('[MediaImageLoader] failed $url: $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      return null;
    }
  }

  /// Reject empty bodies and HTML/JSON error pages cached from failed proxy responses.
  static bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 12) return false;
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // WEBP (RIFF....WEBP)
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes.length >= 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    return false;
  }

  static String _extFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.png')) return 'png';
    if (lower.contains('.webp')) return 'webp';
    return 'jpg';
  }
}
