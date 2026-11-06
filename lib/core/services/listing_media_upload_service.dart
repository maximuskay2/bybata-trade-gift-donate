import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../config/env_config.dart';
import '../../features/storage/repository/storage_repository.dart';
import '../models/listing_media.dart';
import '../utils/media_utils.dart';
import '../widgets/listing_creation_progress.dart';

/// Uploads listing images or a single video to S3 via presigned URLs.
class ListingMediaUploadService {
  /// Returns API body fields: `mediaType`, `videoKey`, `thumbnailKey`, and/or `mediaKeys`.
  static Future<Map<String, dynamic>> uploadDraft({
    required ListingMediaDraft draft,
    required String domain,
    Dio? dio,
    ListingCreationReporter? onProgress,
  }) async {
    if (draft.isEmpty) return {};
    onProgress?.call(0.08, 'Preparing media…');

    if (draft.mediaType == ListingMediaType.video) {
      final path = draft.videoPath;
      if (path == null || path.isEmpty) return {};
      onProgress?.call(0.15, 'Uploading video…');
      final key = await uploadVideo(localPath: path, domain: domain, dio: dio);
      if (key == null) throw Exception('Video upload failed');

      String? thumbnailKey;
      final thumbPath = draft.videoThumbnailPath;
      if (thumbPath != null && thumbPath.isNotEmpty) {
        onProgress?.call(0.55, 'Uploading video thumbnail…');
        final keys = await uploadImages(
          localPaths: [thumbPath],
          domain: domain,
          dio: dio,
        );
        if (keys.isNotEmpty) thumbnailKey = keys.first;
      }
      onProgress?.call(0.78, 'Media uploaded');

      final payload = {
        'mediaType': 'VIDEO',
        'videoKey': key,
        if (thumbnailKey != null) 'thumbnailKey': thumbnailKey,
        'mediaKeys': <String>[],
      };
      await warmUploadedMedia(payload);
      return payload;
    }

    final paths = draft.imagePaths;
    final keys = <String>[];
    for (var i = 0; i < paths.length; i++) {
      onProgress?.call(
        0.12 + (0.66 * (i + 1) / paths.length),
        paths.length == 1
            ? 'Uploading photo…'
            : 'Uploading photo ${i + 1} of ${paths.length}…',
      );
      final batch = await uploadImages(
        localPaths: [paths[i]],
        domain: domain,
        dio: dio,
      );
      keys.addAll(batch);
    }
    if (keys.isEmpty && paths.isNotEmpty) {
      throw Exception('Image upload failed');
    }
    onProgress?.call(0.78, 'Media uploaded');
    final payload = {'mediaType': 'IMAGE', 'mediaKeys': keys};
    await warmUploadedMedia(payload);
    return payload;
  }

  /// Pre-resolve storage keys so hub feed cards can render immediately after create.
  static Future<void> warmUploadedMedia(Map<String, dynamic> uploaded) async {
    final mediaType = (uploaded['mediaType'] as String?)?.toUpperCase();
    final videoKey = uploaded['videoKey']?.toString();
    final thumbnailKey = uploaded['thumbnailKey']?.toString();
    final mediaKeys = (uploaded['mediaKeys'] as List?)?.cast<String>() ?? const [];

    if (mediaType == 'VIDEO') {
      if (videoKey != null && videoKey.isNotEmpty) {
        await MediaResolver.resolveUrl(videoKey, forVideo: true);
      }
      if (thumbnailKey != null && thumbnailKey.isNotEmpty) {
        await MediaResolver.resolveUrl(thumbnailKey);
      }
      return;
    }

    for (final key in mediaKeys) {
      if (key.trim().isEmpty) continue;
      await MediaResolver.resolveUrl(key);
    }
  }

  /// Resolves edit-flow media (kept remote + newly picked) into API patch fields.
  static Future<Map<String, dynamic>> resolveEditMediaForApi({
    required EditableListingMediaState state,
    required String domain,
    ListingCreationReporter? onProgress,
  }) async {
    if (!state.hasMedia) {
      throw Exception('Add at least one photo or a video');
    }

    if (state.mediaType == ListingMediaType.video) {
      if (state.newVideoPath != null && state.newVideoPath!.isNotEmpty) {
        return uploadDraft(
          draft: ListingMediaDraft(
            mediaType: ListingMediaType.video,
            videoPath: state.newVideoPath,
            videoThumbnailPath: state.newVideoThumbnailPath,
          ),
          domain: domain,
          onProgress: onProgress,
        );
      }
      final key = state.keptVideoKey?.trim();
      if (key != null && key.isNotEmpty) {
        return {
          'mediaType': 'VIDEO',
          'videoKey': key,
          if (state.keptThumbnailKey != null) 'thumbnailKey': state.keptThumbnailKey,
          'mediaKeys': <String>[],
        };
      }
      throw Exception('Add a video');
    }

    if (state.totalImageCount > 5) {
      throw Exception('Maximum 5 images allowed');
    }

    final keys = <String>[...state.keptImageKeys];
    if (state.newImageFiles.isNotEmpty) {
      onProgress?.call(0.2, 'Uploading photos…');
      final uploaded = await uploadImages(
        localPaths: state.newImageFiles.map((f) => f.path).toList(),
        domain: domain,
      );
      keys.addAll(uploaded);
    }
    if (keys.isEmpty) {
      throw Exception('Add at least one photo');
    }
    onProgress?.call(0.78, 'Media uploaded');
    return {
      'mediaType': 'IMAGE',
      'mediaKeys': keys,
      'videoKey': null,
      'thumbnailKey': keys.first,
    };
  }

  static Future<String?> uploadVideo({
    required String localPath,
    required String domain,
    Dio? dio,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) return null;
    final client = dio ?? await _defaultDio();
    final storageRepo = StorageRepository(client);
    try {
      final bytes = await file.readAsBytes();
      final lower = localPath.toLowerCase();
      final ext = lower.endsWith('.mov') ? 'mov' : 'mp4';
      final contentType = ext == 'mov' ? 'video/quicktime' : 'video/mp4';
      final meta = await storageRepo.createUploadUrl(
        domain: domain,
        ext: ext,
        contentType: contentType,
      );
      final uploadUrl = meta['uploadUrl'] as String?;
      final key = meta['key'] as String?;
      if (uploadUrl == null || key == null) return null;
      await storageRepo.uploadToSignedUrl(
        uploadUrl: uploadUrl,
        bytes: bytes,
        contentType: contentType,
      );
      return key;
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> uploadImages({
    required List<String> localPaths,
    required String domain,
    Dio? dio,
  }) async {
    if (localPaths.isEmpty) return [];
    final client = dio ?? await _defaultDio();
    final storageRepo = StorageRepository(client);
    final keys = <String>[];
    for (final path in localPaths) {
      try {
        final file = File(path);
        if (!file.existsSync()) continue;
        final bytes = await file.readAsBytes();
        final ext = _inferExt(path);
        final contentType = _contentTypeFromExt(ext);
        final meta = await storageRepo.createUploadUrl(
          domain: domain,
          ext: ext,
          contentType: contentType,
        );
        final uploadUrl = meta['uploadUrl'] as String?;
        final key = meta['key'] as String?;
        if (uploadUrl == null || key == null) continue;
        await storageRepo.uploadToSignedUrl(
          uploadUrl: uploadUrl,
          bytes: bytes,
          contentType: contentType,
        );
        keys.add(key);
      } catch (_) {
        // skip failed file
      }
    }
    return keys;
  }

  static Future<Dio> _defaultDio() async {
    final baseUrl = await EnvConfig.getBaseUrl();
    final client = ApiClient(baseUrl, const FlutterSecureStorage());
    return client.dio;
  }

  static String _inferExt(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.gif')) return 'gif';
    return 'jpg';
  }

  static String _contentTypeFromExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}
