import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

import 'image_resize_utils.dart';

/// Result of preparing a local video for listing upload.
class ProcessedVideoResult {
  final String videoPath;
  final String thumbnailPath;
  final int durationMs;
  final int originalBytes;
  final int compressedBytes;

  const ProcessedVideoResult({
    required this.videoPath,
    required this.thumbnailPath,
    required this.durationMs,
    required this.originalBytes,
    required this.compressedBytes,
  });
}

/// Compresses videos, generates 16:10 thumbnails, and enforces a 1-minute cap.
class VideoProcessingUtils {
  VideoProcessingUtils._();

  static const Duration maxDuration = Duration(seconds: 60);
  static const int maxDurationMs = 60000;

  /// Validates duration, compresses video, and builds a JPEG poster frame.
  static Future<ProcessedVideoResult?> prepareForUpload(
    String sourcePath, {
    void Function(double progress)? onProgress,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync()) return null;

    final originalBytes = await source.length();
    Subscription? sub;
    if (onProgress != null) {
      sub = VideoCompress.compressProgress$.subscribe((p) {
        onProgress(p / 100.0);
      });
    }

    try {
      final info = await VideoCompress.getMediaInfo(sourcePath);
      final durationMs = info.duration?.toInt() ?? 0;
      if (durationMs > maxDurationMs + 500) {
        return null;
      }

      final thumbFile = await VideoCompress.getFileThumbnail(
        sourcePath,
        quality: 75,
        position: durationMs > 1000 ? 1000 : 0,
      );
      // Center-crop thumbnail to feed 16:10 so posters match timeline cards.
      final resizedThumb =
          await ImageResizeUtils.resizeToFeedAspectFile(thumbFile);

      final compressed = await VideoCompress.compressVideo(
        sourcePath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 24,
      );

      final outputPath = compressed?.path;
      if (outputPath == null || outputPath.isEmpty) {
        return ProcessedVideoResult(
          videoPath: sourcePath,
          thumbnailPath: resizedThumb.path,
          durationMs: durationMs,
          originalBytes: originalBytes,
          compressedBytes: originalBytes,
        );
      }

      final outFile = File(outputPath);
      final compressedBytes =
          outFile.existsSync() ? await outFile.length() : originalBytes;

      return ProcessedVideoResult(
        videoPath: outputPath,
        thumbnailPath: resizedThumb.path,
        durationMs: compressed?.duration?.toInt() ?? durationMs,
        originalBytes: originalBytes,
        compressedBytes: compressedBytes,
      );
    } catch (e) {
      debugPrint('[VideoProcessingUtils] prepareForUpload failed: $e');
      return null;
    } finally {
      sub?.unsubscribe();
    }
  }

  static Future<void> cancelInFlight() async {
    try {
      await VideoCompress.cancelCompression();
    } catch (_) {}
  }

  static String formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
