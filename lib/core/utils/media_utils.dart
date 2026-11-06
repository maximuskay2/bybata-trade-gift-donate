import 'package:flutter/foundation.dart';
import '../config/env_config.dart';
import 'cache_store.dart';

class MediaResolver {
  /// Stable object-proxy URLs are keyed by storage key — long TTL is safe.
  static final CacheStore<String, String> _urlCache =
      CacheStore<String, String>(ttl: const Duration(hours: 24));

  static final CacheStore<String, String> _filePathCache =
      CacheStore<String, String>(ttl: const Duration(days: 7));

  static String? _cachedBaseUrl;
  static Future<String>? _baseUrlFuture;
  static final Map<String, Future<String?>> _inFlight = {};

  /// Formats Android [ImageDecoder] often cannot decode (JNI "unimplemented").
  static const List<String> _androidUnsupportedExt = [
    '.heic',
    '.heif',
    '.heics',
    '.heifs',
    '.avif',
    '.svg',
    '.bmp',
    '.tif',
    '.tiff',
  ];

  /// Returns false when [urlOrKey] points at a format likely to fail on Android.
  static bool isDecodableImageUrl(String? urlOrKey) {
    if (urlOrKey == null || urlOrKey.isEmpty) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return true;

    final haystack = _imagePathHaystack(urlOrKey);
    for (final ext in _androidUnsupportedExt) {
      if (haystack.contains(ext)) return false;
    }
    return true;
  }

  static String _imagePathHaystack(String urlOrKey) {
    final parts = <String>[urlOrKey.toLowerCase()];
    try {
      final uri = Uri.parse(urlOrKey);
      parts.add(uri.path.toLowerCase());
      final key = uri.queryParameters['key'];
      if (key != null && key.isNotEmpty) {
        parts.add(key.toLowerCase());
      }
    } catch (_) {}
    return parts.join(' ');
  }

  /// Preload API base URL so first media resolve does not block the UI.
  static Future<void> warmBaseUrl() async {
    await _resolveBaseUrl();
  }

  /// Call when the user switches API environments.
  static void invalidateBaseUrl() {
    _cachedBaseUrl = null;
    _baseUrlFuture = null;
    _urlCache.invalidate();
  }

  static Future<String> _resolveBaseUrl() async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    _baseUrlFuture ??= EnvConfig.getBaseUrl().then((url) {
      _cachedBaseUrl = url;
      return url;
    });
    return _baseUrlFuture!;
  }

  /// Synchronous cache lookup — use to skip loading spinners on revisits.
  static String? peekCachedUrl(String? key) {
    if (key == null || key.isEmpty) return null;
    if (key.startsWith('http://') || key.startsWith('https://')) {
      return _normalizeForEmulator(key);
    }
    return _urlCache.getIfFresh(key);
  }

  static String? peekCachedFilePath(String key) =>
      _filePathCache.getIfFresh(key);

  static void rememberCachedFilePath(String key, String path) {
    _filePathCache.set(key, path);
  }

  /// Pre-seed URL cache from list API (`thumbnailUrl`, etc.) to skip resolve round-trips.
  static void rememberResolvedUrl(String? key, String? url) {
    if (key == null || key.isEmpty || url == null || url.isEmpty) return;
    if (key.startsWith('http://') || key.startsWith('https://')) return;
    _urlCache.set(key, _normalizeForEmulator(url));
  }

  /// Batch warm URL cache from API list payloads.
  static void seedUrlsFromListingMaps(Iterable<Map<String, dynamic>> items) {
    for (final item in items) {
      final thumbKey = item['thumbnailKey']?.toString();
      final thumbUrl = item['thumbnailUrl']?.toString();
      if (thumbKey != null && thumbUrl != null) {
        rememberResolvedUrl(thumbKey, thumbUrl);
      }
      final previewUrl = item['previewImageUrl']?.toString();
      if (previewUrl != null && thumbKey != null) {
        rememberResolvedUrl(thumbKey, previewUrl);
      }
      if (previewUrl != null) {
        final mediaKeys = item['mediaKeys'];
        if (mediaKeys is List && mediaKeys.isNotEmpty) {
          final mk = mediaKeys.first?.toString();
          if (mk != null && mk.isNotEmpty) {
            rememberResolvedUrl(mk, previewUrl);
          }
        }
      }
      final avatarKey = item['owner']?['profile']?['avatarKey'] ??
          item['giver']?['profile']?['avatarKey'] ??
          item['founder']?['profile']?['avatarKey'];
      final avatarUrl = item['ownerAvatarUrl']?.toString();
      if (avatarKey is String && avatarUrl != null) {
        rememberResolvedUrl(avatarKey, avatarUrl);
      }
    }
  }

  /// Batch-resolve storage keys (deduped, cache-aware).
  static Future<List<String>> resolveUrls(
    List<String> keys, {
    bool forVideo = false,
  }) async {
    final urls = <String>[];
    for (final raw in keys) {
      final key = raw.trim();
      if (key.isEmpty) continue;
      final url = await resolveUrl(key, forVideo: forVideo);
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      }
    }
    return urls;
  }

  /// Resolves a storage key to a stable object-proxy URL (cached in memory).
  /// Returns normalized absolute URLs unchanged.
  static Future<String?> resolveUrl(String? key, {bool forVideo = false}) async {
    if (key == null || key.isEmpty) return null;
    if (!forVideo && !isDecodableImageUrl(key)) return null;

    try {
      final parsed = Uri.parse(key);
      if (parsed.scheme == 'file') return null;
    } catch (_) {}

    if (key.startsWith('http://') || key.startsWith('https://')) {
      try {
        final uri = Uri.parse(key);
        final isObjectPath = uri.path.contains('/v1/storage/object');
        final k = uri.queryParameters['key'] ?? '';
        final looksLikeLocalTemp = k.startsWith('/') &&
            (k.contains('/tmp/image_picker') ||
                k.contains('/Containers/Data/Application'));
        if (isObjectPath && looksLikeLocalTemp) return null;

        if (!kReleaseMode &&
            (uri.host == 'localhost' || uri.host == '127.0.0.1') &&
            uri.port == 9000) {
          return null;
        }

        final normalized = _normalizeForEmulator(key);
        if (!forVideo && !isDecodableImageUrl(normalized)) return null;
        return normalized;
      } catch (_) {
        return null;
      }
    }

    final cached = _urlCache.getIfFresh(key);
    if (cached != null) return cached;

    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final future = _resolveStorageKey(key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<String?> _resolveStorageKey(String key) async {
    final cached = _urlCache.getIfFresh(key);
    if (cached != null) return cached;

    final base = await _resolveBaseUrl();

    try {
      final baseUri = Uri.parse(base);
      final objectUri = baseUri.replace(
        path: '/v1/storage/object',
        queryParameters: {'key': key},
      );
      final url = _normalizeForEmulator(objectUri.toString());
      _urlCache.set(key, url);
      return url;
    } catch (_) {
      return null;
    }
  }

  static String _normalizeForEmulator(String url) {
    if (kIsWeb) return url;
    if (defaultTargetPlatform != TargetPlatform.android) return url;
    try {
      final uri = Uri.parse(url);
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
        return uri.replace(host: '10.0.2.2').toString();
      }
      return url;
    } catch (_) {
      return url;
    }
  }
}

/// Alias used by listing media widgets.
Future<String?> resolveListingMediaUrl(String keyOrUrl) =>
    MediaResolver.resolveUrl(keyOrUrl, forVideo: true);
