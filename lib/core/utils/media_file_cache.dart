import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'media_utils.dart';

/// Playback source for listing videos — local file or streaming URL.
class ListingVideoSource {
  final File? file;
  final String? streamUrl;

  const ListingVideoSource({this.file, this.streamUrl});

  bool get isValid => file != null || (streamUrl != null && streamUrl!.isNotEmpty);
}

/// Disk cache for listing videos keyed by storage key.
class MediaFileCache {
  MediaFileCache._();

  static final CacheManager _manager = CacheManager(
    Config(
      'bybata_listing_media',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 300,
    ),
  );

  static final Set<String> _prefetchInFlight = {};

  /// Returns a cached local file if already on disk — never downloads.
  static Future<File?> getCachedFile(String storageKey) async {
    final key = storageKey.trim();
    if (key.isEmpty) return null;

    final fromMemory = _fileFromRememberedPath(key);
    if (fromMemory != null) return fromMemory;

    try {
      final info = await _manager.getFileFromCache(key);
      if (info != null && await info.file.exists()) {
        MediaResolver.rememberCachedFilePath(key, info.file.path);
        return info.file;
      }
    } catch (_) {}

    return null;
  }

  /// Fast path for playback: cached file if ready, otherwise streaming URL.
  static Future<ListingVideoSource> resolveForPlayback(String storageKey) async {
    final key = storageKey.trim();
    if (key.isEmpty) return const ListingVideoSource();

    final cached = await getCachedFile(key);
    if (cached != null) {
      return ListingVideoSource(file: cached);
    }

    final url = await MediaResolver.resolveUrl(key, forVideo: true);
    if (url == null || url.isEmpty) return const ListingVideoSource();

    // Warm full-file cache in the background for repeat views.
    prefetch(key);

    return ListingVideoSource(streamUrl: url);
  }

  /// Downloads the full file in the background (does not block playback).
  static void prefetch(String storageKey) {
    final key = storageKey.trim();
    if (key.isEmpty || _prefetchInFlight.contains(key)) return;
    if (MediaResolver.peekCachedFilePath(key) != null) return;

    _prefetchInFlight.add(key);
    unawaited(_downloadToCache(key).whenComplete(() => _prefetchInFlight.remove(key)));
  }

  static Future<void> prefetchAll(Iterable<String> storageKeys) async {
    for (final raw in storageKeys) {
      final key = raw.trim();
      if (key.isEmpty) continue;
      // Warm URL cache synchronously cheap; download runs in background.
      await MediaResolver.resolveUrl(key, forVideo: true);
      prefetch(key);
    }
  }

  /// @deprecated Prefer [resolveForPlayback] — this blocked until full download.
  static Future<File?> getFile(String storageKey) async {
    final cached = await getCachedFile(storageKey);
    if (cached != null) return cached;
    return _downloadToCache(storageKey.trim());
  }

  static Future<File?> _downloadToCache(String key) async {
    if (key.isEmpty) return null;

    final existing = await getCachedFile(key);
    if (existing != null) return existing;

    final url = await MediaResolver.resolveUrl(key, forVideo: true);
    if (url == null || url.isEmpty) return null;

    try {
      final file = await _manager.getSingleFile(url, key: key);
      MediaResolver.rememberCachedFilePath(key, file.path);
      return file;
    } catch (_) {
      return null;
    }
  }

  static File? _fileFromRememberedPath(String key) {
    final cachedPath = MediaResolver.peekCachedFilePath(key);
    if (cachedPath == null) return null;
    final file = File(cachedPath);
    return file.existsSync() ? file : null;
  }
}

/// Warms video URLs and background cache for listing video keys.
class ListingVideoPrefetch {
  ListingVideoPrefetch._();

  static void warmKeys(Iterable<String> videoKeys, {int limit = 8}) {
    final keys = <String>[];
    for (final raw in videoKeys) {
      if (keys.length >= limit) break;
      final key = raw.trim();
      if (key.isNotEmpty) keys.add(key);
    }
    if (keys.isEmpty) return;
    unawaited(MediaFileCache.prefetchAll(keys));
  }

  /// Directional window: [anchor - behind] .. [anchor + ahead].
  static void prefetchWindow({
    required List<String> videoKeys,
    required int anchorIndex,
    int ahead = 2,
    int behind = 1,
  }) {
    if (videoKeys.isEmpty) return;
    final anchor = anchorIndex.clamp(0, videoKeys.length - 1);
    final start = (anchor - behind).clamp(0, videoKeys.length - 1);
    final end = (anchor + ahead).clamp(0, videoKeys.length - 1);
    for (var i = start; i <= end; i++) {
      final key = videoKeys[i];
      unawaited(MediaResolver.resolveUrl(key, forVideo: true));
      MediaFileCache.prefetch(key);
    }
  }

  static List<String> videoKeysFromFeedItems(Iterable<dynamic> items) {
    final keys = <String>[];
    for (final item in items) {
      final key = _readVideoKey(item);
      if (key != null && key.isNotEmpty) keys.add(key);
    }
    return keys;
  }

  static List<String> videoKeysFromSearchMaps(Iterable<Map<String, dynamic>> items) {
    final keys = <String>[];
    for (final item in items) {
      final mediaType = item['mediaType']?.toString().toUpperCase();
      final videoKey = item['videoKey']?.toString().trim();
      final isVideo = mediaType == 'VIDEO' ||
          (videoKey != null && videoKey.isNotEmpty);
      if (!isVideo || videoKey == null || videoKey.isEmpty) continue;
      keys.add(videoKey);
    }
    return keys;
  }

  /// Scroll-driven prefetch aligned to feed item indices (2 ahead / 1 behind).
  static void prefetchItemWindow({
    required Iterable<dynamic> items,
    required int anchorIndex,
    int ahead = 2,
    int behind = 1,
  }) {
    final list = items.toList();
    if (list.isEmpty) return;
    final anchor = anchorIndex.clamp(0, list.length - 1);
    final start = (anchor - behind).clamp(0, list.length - 1);
    final end = (anchor + ahead).clamp(0, list.length - 1);
    for (var i = start; i <= end; i++) {
      warmListingMedia(
        videoKey: _readVideoKey(list[i]),
        thumbnailKey: _readThumbnailKey(list[i]),
      );
    }
  }

  /// Scroll-driven prefetch for vertical feeds (2 ahead / 1 behind by default).
  static void prefetchForScroll({
    required double scrollOffset,
    required double lastScrollOffset,
    required Iterable<dynamic> items,
    double estimatedItemExtent = 560,
    int ahead = 2,
    int behind = 1,
  }) {
    final list = items.toList();
    if (list.isEmpty) return;
    if ((scrollOffset - lastScrollOffset).abs() < 4) return;

    final scrollingDown = scrollOffset > lastScrollOffset;
    final anchor = (scrollOffset / estimatedItemExtent)
        .floor()
        .clamp(0, list.length - 1);

    prefetchItemWindow(
      items: list,
      anchorIndex: anchor,
      ahead: scrollingDown ? ahead : behind,
      behind: scrollingDown ? behind : ahead,
    );
  }

  /// Prefetch video + poster URL as soon as listing metadata is known.
  static void warmListingMedia({String? videoKey, String? thumbnailKey}) {
    final vk = videoKey?.trim();
    if (vk != null && vk.isNotEmpty) {
      unawaited(MediaResolver.resolveUrl(vk, forVideo: true));
      MediaFileCache.prefetch(vk);
    }
    final tk = thumbnailKey?.trim();
    if (tk != null && tk.isNotEmpty) {
      unawaited(MediaResolver.resolveUrl(tk));
    }
  }

  static void warmFeedItems(Iterable<dynamic> items, {int limit = 10}) {
    final videoKeys = <String>[];
    final imageKeys = <String>[];
    for (final item in items) {
      if (videoKeys.length + imageKeys.length >= limit) break;
      final videoKey = _readVideoKey(item);
      if (videoKey != null && videoKey.isNotEmpty) {
        videoKeys.add(videoKey);
        continue;
      }
      final thumb = _readThumbnailKey(item) ?? _readPreviewImageKey(item);
      if (thumb != null && thumb.isNotEmpty) imageKeys.add(thumb);
    }
    if (videoKeys.isNotEmpty) {
      unawaited(MediaFileCache.prefetchAll(videoKeys));
    }
    prefetchFeedImages(imageKeys);
  }

  static void prefetchFeedImages(Iterable<String> keys) {
    for (final raw in keys) {
      final key = raw.trim();
      if (key.isEmpty) continue;
      unawaited(MediaResolver.resolveUrl(key));
    }
  }

  static String? _readPreviewImageKey(dynamic item) {
    if (item is Map) {
      final url = item['previewImageUrl'] ?? item['thumbnailUrl'];
      if (url is String && url.startsWith('http')) {
        final key = item['thumbnailKey']?.toString();
        if (key != null && key.isNotEmpty) {
          MediaResolver.rememberResolvedUrl(key, url);
        }
      }
      final mk = item['mediaKeys'];
      if (mk is List && mk.isNotEmpty) {
        return mk.first?.toString();
      }
    }
    try {
      final dynamic preview = (item as dynamic).previewImageUrl;
      if (preview is String && preview.isNotEmpty) return null;
    } catch (_) {}
    return null;
  }

  static String? _readVideoKey(dynamic item) {
    if (item is Map) {
      final direct = item['videoKey']?.toString();
      if (direct != null && direct.isNotEmpty) return direct;
      final mediaType = item['mediaType']?.toString().toUpperCase();
      if (mediaType == 'VIDEO') return direct;
      return null;
    }
    try {
      final dynamic media = (item as dynamic).media;
      if (media != null && media.isVideo == true) {
        final videoKey = media.videoKey?.toString();
        if (videoKey != null && videoKey.isNotEmpty) return videoKey;
      }
    } catch (_) {}
    try {
      final dynamic listingMedia = (item as dynamic).listingMedia;
      if (listingMedia != null && listingMedia.isVideo == true) {
        return listingMedia.videoKey?.toString();
      }
    } catch (_) {}
    try {
      return (item as dynamic).videoKey?.toString();
    } catch (_) {}
    return null;
  }

  static String? _readThumbnailKey(dynamic item) {
    if (item is Map) {
      return item['thumbnailKey']?.toString();
    }
    try {
      final dynamic media = (item as dynamic).media;
      if (media != null) {
        final preview = media.previewImageKey?.toString();
        if (preview != null && preview.isNotEmpty) return preview;
      }
    } catch (_) {}
    try {
      return (item as dynamic).media?.thumbnailKey?.toString();
    } catch (_) {}
    return null;
  }
}
