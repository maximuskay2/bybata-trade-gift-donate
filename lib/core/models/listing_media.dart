/// Picture-or-video media for trades, gifts, and campaigns (mutually exclusive).
import 'dart:io';

enum ListingMediaType { image, video }

class ListingMediaFields {
  final ListingMediaType mediaType;
  final List<String> mediaKeys;
  final String? videoKey;
  /// Poster frame for video listings (feed cards, picker preview after upload).
  final String? thumbnailKey;

  const ListingMediaFields({
    this.mediaType = ListingMediaType.image,
    this.mediaKeys = const [],
    this.videoKey,
    this.thumbnailKey,
  });

  bool get isVideo {
    if (mediaType == ListingMediaType.video &&
        videoKey != null &&
        videoKey!.trim().isNotEmpty) {
      return true;
    }
    return videoKey != null &&
        videoKey!.trim().isNotEmpty &&
        mediaKeys.isEmpty;
  }

  bool get hasMedia => isVideo || mediaKeys.isNotEmpty;

  static bool isLikelyVideoKey(String? key) {
    if (key == null || key.trim().isEmpty) return false;
    final lower = key.trim().toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m4v');
  }

  String? get _resolvedThumbnailKey {
    final explicit = thumbnailKey?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final video = videoKey?.trim();
    for (final raw in mediaKeys) {
      final key = raw.trim();
      if (key.isEmpty) continue;
      if (video != null && key == video) continue;
      if (!isLikelyVideoKey(key)) return key;
    }
    return null;
  }

  /// Best image key for cards: video poster or first photo.
  String? get previewImageKey {
    final thumb = _resolvedThumbnailKey;
    if (thumb != null) return thumb;
    if (!isVideo && mediaKeys.isNotEmpty) return mediaKeys.first;
    return null;
  }

  /// Lightweight media for browse feeds — poster/thumbnail only, no inline video.
  ListingMediaFields get feedPreview {
    final preview = previewImageKey;
    if (isVideo) {
      return ListingMediaFields(
        mediaType: ListingMediaType.image,
        mediaKeys: preview != null ? [preview] : const [],
        thumbnailKey: preview,
      );
    }
    if (preview == null) return const ListingMediaFields();
    return ListingMediaFields(
      mediaType: ListingMediaType.image,
      mediaKeys: [preview],
      thumbnailKey: preview,
    );
  }

  String get apiMediaType =>
      mediaType == ListingMediaType.video ? 'VIDEO' : 'IMAGE';

  static ListingMediaFields fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ListingMediaFields();
    final typeStr = (json['mediaType'] ?? 'IMAGE').toString().toUpperCase();
    final mediaKeys = _parseMediaKeys(json['mediaKeys']);
    final videoKey = _trimOrNull(json['videoKey']);
    final thumbnailKey = _trimOrNull(json['thumbnailKey']);
    final isVideo = typeStr == 'VIDEO' ||
        ((videoKey ?? '').isNotEmpty && mediaKeys.isEmpty);
    return ListingMediaFields(
      mediaType: isVideo ? ListingMediaType.video : ListingMediaType.image,
      mediaKeys: mediaKeys,
      videoKey: videoKey,
      thumbnailKey: thumbnailKey,
    );
  }

  static List<String> _parseMediaKeys(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((k) => k.isNotEmpty)
        .toList();
  }

  static String? _trimOrNull(dynamic value) {
    final trimmed = value?.toString().trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

/// Local selection before upload (create / edit flows).
class ListingMediaDraft {
  final ListingMediaType mediaType;
  final List<String> imagePaths;
  final String? videoPath;
  final String? videoThumbnailPath;

  const ListingMediaDraft({
    this.mediaType = ListingMediaType.image,
    this.imagePaths = const [],
    this.videoPath,
    this.videoThumbnailPath,
  });

  bool get isEmpty =>
      mediaType == ListingMediaType.video
          ? videoPath == null || videoPath!.isEmpty
          : imagePaths.isEmpty;
}

/// Edit-flow media state: kept remote keys + new local picks (photos or one video).
class EditableListingMediaState {
  final ListingMediaType mediaType;
  final List<String> keptImageKeys;
  final String? keptVideoKey;
  final String? keptThumbnailKey;
  final List<File> newImageFiles;
  final String? newVideoPath;
  final String? newVideoThumbnailPath;

  const EditableListingMediaState({
    this.mediaType = ListingMediaType.image,
    this.keptImageKeys = const [],
    this.keptVideoKey,
    this.keptThumbnailKey,
    this.newImageFiles = const [],
    this.newVideoPath,
    this.newVideoThumbnailPath,
  });

  factory EditableListingMediaState.fromExisting(ListingMediaFields existing) {
    if (existing.isVideo) {
      return EditableListingMediaState(
        mediaType: ListingMediaType.video,
        keptVideoKey: existing.videoKey,
        keptThumbnailKey: existing.thumbnailKey,
      );
    }
    return EditableListingMediaState(
      mediaType: ListingMediaType.image,
      keptImageKeys: List<String>.from(existing.mediaKeys),
    );
  }

  int get totalImageCount => keptImageKeys.length + newImageFiles.length;

  bool get hasMedia {
    if (mediaType == ListingMediaType.video) {
      return (newVideoPath != null && newVideoPath!.isNotEmpty) ||
          (keptVideoKey != null && keptVideoKey!.trim().isNotEmpty);
    }
    return totalImageCount > 0;
  }

  EditableListingMediaState copyWith({
    ListingMediaType? mediaType,
    List<String>? keptImageKeys,
    String? keptVideoKey,
    String? keptThumbnailKey,
    List<File>? newImageFiles,
    String? newVideoPath,
    String? newVideoThumbnailPath,
    bool clearVideo = false,
    bool clearImages = false,
  }) {
    return EditableListingMediaState(
      mediaType: mediaType ?? this.mediaType,
      keptImageKeys: clearImages ? const [] : (keptImageKeys ?? this.keptImageKeys),
      keptVideoKey: clearVideo ? null : (keptVideoKey ?? this.keptVideoKey),
      keptThumbnailKey: clearVideo ? null : (keptThumbnailKey ?? this.keptThumbnailKey),
      newImageFiles: clearImages ? const [] : (newImageFiles ?? this.newImageFiles),
      newVideoPath: clearVideo ? null : (newVideoPath ?? this.newVideoPath),
      newVideoThumbnailPath:
          clearVideo ? null : (newVideoThumbnailPath ?? this.newVideoThumbnailPath),
    );
  }
}
