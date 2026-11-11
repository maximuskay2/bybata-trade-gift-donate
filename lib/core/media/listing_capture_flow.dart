import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/listing_media_constants.dart';
import '../utils/video_processing_utils.dart';
import '../widgets/app_toast.dart';
import 'clip_prepare.dart';
import 'hero_capture_page.dart';
import 'stage_review_page.dart';
import 'subject_cutout.dart';

/// Photo and video entry for every listing picker.
class ListingCaptureFlow {
  ListingCaptureFlow._();

  static Future<File?> takePhoto(
    BuildContext context, {
    required Color stageColor,
  }) {
    return _photoLoop(context, stageColor: stageColor, fromCamera: true);
  }

  static Future<File?> acceptGalleryPhoto(
    BuildContext context, {
    required String sourcePath,
    required Color stageColor,
  }) {
    return _photoLoop(
      context,
      stageColor: stageColor,
      fromCamera: false,
      galleryPath: sourcePath,
    );
  }

  static Future<ProcessedVideoResult?> takeVideo(
    BuildContext context, {
    required Color stageColor,
    void Function(double progress)? onProgress,
  }) {
    return _videoLoop(context, stageColor: stageColor, onProgress: onProgress);
  }

  static Future<ProcessedVideoResult?> acceptGalleryVideo(
    BuildContext context, {
    required String sourcePath,
    required Color stageColor,
    void Function(double progress)? onProgress,
  }) {
    return _finishVideo(
      context,
      sourcePath: sourcePath,
      stageColor: stageColor,
      offerRetake: false,
      onProgress: onProgress,
    );
  }

  static Future<File?> _photoLoop(
    BuildContext context, {
    required Color stageColor,
    required bool fromCamera,
    String? galleryPath,
  }) async {
    if (kIsWeb) {
      AppToast.show(context, 'Take the photo in the iOS or Android app.');
      return null;
    }
    if (!await _warm(context) || !context.mounted) return null;
    while (context.mounted) {
      final raw = fromCamera
          ? await HeroCapturePage.open(context)
          : galleryPath;
      if (raw == null || !context.mounted) return null;
      final exit = await StageReviewPage.open(
        context,
        sourcePath: raw,
        stageColor: stageColor,
        offerRetake: fromCamera,
      );
      if (!context.mounted) return null;
      if (exit?.file != null) return exit!.file;
      if (exit?.retake != true) return null;
      galleryPath = null;
    }
    return null;
  }

  static Future<ProcessedVideoResult?> _videoLoop(
    BuildContext context, {
    required Color stageColor,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      AppToast.show(context, 'Record the clip in the iOS or Android app.');
      return null;
    }
    if (!await _warm(context) || !context.mounted) return null;
    if (Platform.isAndroid) {
      await Permission.microphone.request();
    }
    if (!context.mounted) return null;
    while (context.mounted) {
      final raw = await HeroCapturePage.open(context, recordVideo: true);
      if (raw == null || !context.mounted) return null;
      final result = await _finishVideo(
        context,
        sourcePath: raw,
        stageColor: stageColor,
        offerRetake: true,
        onProgress: onProgress,
      );
      if (result != null) return result;
      if (!context.mounted) return null;
    }
    return null;
  }

  static Future<ProcessedVideoResult?> _finishVideo(
    BuildContext context, {
    required String sourcePath,
    required Color stageColor,
    required bool offerRetake,
    void Function(double progress)? onProgress,
  }) async {
    final prepared = await HeroClipPrep.run(sourcePath);
    if (!context.mounted) return null;
    if (prepared.refusal != null) {
      try {
        await File(sourcePath).delete();
      } catch (_) {}
      if (context.mounted) AppToast.show(context, prepared.refusal!);
      return null;
    }
    final clipPath = prepared.path ?? sourcePath;
    final poster = await VideoCompressThumbnail.file(clipPath);
    if (!context.mounted) return null;
    if (poster == null) {
      AppToast.show(context, 'Could not read a frame from that clip.');
      return null;
    }
    final exit = await StageReviewPage.open(
      context,
      sourcePath: poster,
      stageColor: stageColor,
      offerRetake: offerRetake,
    );
    if (exit?.file == null || !context.mounted) return null;
    onProgress?.call(0.1);
    final processed = await VideoProcessingUtils.prepareForUpload(
      clipPath,
      onProgress: onProgress,
      limit: ListingMediaConstants.heroClipMax,
    );
    if (processed == null) {
      if (context.mounted) {
        AppToast.show(context, 'Keep the clip to 8 seconds.');
      }
      return null;
    }
    return ProcessedVideoResult(
      videoPath: processed.videoPath,
      thumbnailPath: exit!.file!.path,
      durationMs: processed.durationMs,
      originalBytes: processed.originalBytes,
      compressedBytes: processed.compressedBytes,
    );
  }

  static Future<bool> _warm(BuildContext context) async {
    if (!Platform.isAndroid) return true;
    try {
      await NativeSubjectCutout.warmUpAndroidModel();
      return true;
    } catch (error) {
      if (context.mounted) AppToast.show(context, '$error'.replaceFirst('Bad state: ', ''));
      return false;
    }
  }
}

/// Poster frame for a clip. Split out so the flow does not grow a second compressor.
class VideoCompressThumbnail {
  VideoCompressThumbnail._();

  static Future<String?> file(String sourcePath) {
    return VideoProcessingUtils.posterFrame(sourcePath);
  }
}
