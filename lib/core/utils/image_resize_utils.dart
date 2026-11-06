import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../constants/listing_media_constants.dart';
import '../config/watermark_config.dart';

/// Utility helpers for normalizing images before upload.
///
/// Currently used to ensure consistent 800x800px images for trades, gifts,
/// donations, and community uploads so that cards look uniform and provide
/// better UI display quality.
class ImageResizeUtils {
  // Target dimensions and approximate byte size limit.
  static const int _targetWidth = 800;
  static const int _targetHeight = 800;
  static const int _maxBytes = 100 * 1024; // 100KB

  /// Resize cropped listing photos to max 1600×1000 (16:10 feed widescreen).
  static Future<File> resizeToFeedAspectFile(
    File file, {
    int quality = 85,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return file;

      const targetW = ListingMediaConstants.targetWidth;
      const targetH = ListingMediaConstants.targetHeight;

      img.Image canvas;
      final srcAspect = decoded.width / decoded.height;
      const targetAspect = targetW / targetH;

      if ((srcAspect - targetAspect).abs() < 0.02) {
        canvas = img.copyResize(
          decoded,
          width: targetW,
          height: targetH,
          interpolation: img.Interpolation.average,
        );
      } else {
        int cropW = decoded.width;
        int cropH = decoded.height;
        if (srcAspect > targetAspect) {
          cropW = (decoded.height * targetAspect).round();
        } else {
          cropH = (decoded.width / targetAspect).round();
        }
        final x = ((decoded.width - cropW) / 2).round();
        final y = ((decoded.height - cropH) / 2).round();
        final cropped = img.copyCrop(
          decoded,
          x: x,
          y: y,
          width: cropW,
          height: cropH,
        );
        canvas = img.copyResize(
          cropped,
          width: targetW,
          height: targetH,
          interpolation: img.Interpolation.average,
        );
      }

      final dir = file.parent;
      final newPath =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${targetW}x${targetH}.jpg';
      final newFile = File(newPath);

      int q = quality;
      List<int> jpgBytes = img.encodeJpg(canvas, quality: q);
      while (jpgBytes.length > _maxBytes && q > 30) {
        q -= 5;
        jpgBytes = img.encodeJpg(canvas, quality: q);
      }
      await newFile.writeAsBytes(jpgBytes, flush: true);
      return newFile;
    } catch (e) {
      debugPrint('[ImageResizeUtils] Error resizing feed-aspect image: $e');
      return file;
    }
  }

  /// Backward-compatible alias — now resizes to 16:10 feed aspect.
  static Future<File> resizeToFourFiveFile(
    File file, {
    int quality = 85,
  }) =>
      resizeToFeedAspectFile(file, quality: quality);

  /// Resize a listing photo to a small JPEG feed thumbnail (~400px wide).
  static Future<File> resizeFeedThumbFile(File file, {int quality = 82}) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return file;

      const targetW = 400;
      final targetH = (targetW * decoded.height / decoded.width).round();
      final resized = img.copyResize(
        decoded,
        width: targetW,
        height: targetH,
        interpolation: img.Interpolation.average,
      );

      final dir = file.parent;
      final newPath =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_feed_thumb.jpg';
      final newFile = File(newPath);
      var q = quality;
      List<int> jpgBytes = img.encodeJpg(resized, quality: q);
      while (jpgBytes.length > 80 * 1024 && q > 40) {
        q -= 5;
        jpgBytes = img.encodeJpg(resized, quality: q);
      }
      await newFile.writeAsBytes(jpgBytes, flush: true);
      return newFile;
    } catch (e) {
      debugPrint('[ImageResizeUtils] feed thumb failed: $e');
      return file;
    }
  }

  /// Reads [file], resizes it to fit within the target 800x800 dimensions while
  /// preserving aspect ratio (no cropping), centers it on a light gray background,
  /// and writes a new JPEG file next to the original.
  ///
  /// This approach ensures all content is visible without any cropping - the image
  /// is scaled down and padded with background if needed to maintain aspect ratio.
  ///
  /// Best-effort compresses the image so the resulting file is at or below
  /// [_maxBytes] by gradually reducing JPEG quality (but never below ~30).
  /// If anything fails (decode error, IO error, etc.), the original [file]
  /// is returned unchanged.
  static Future<File> resizeToSquareFile(
    File file, {
    int size = 600, // kept for backwards compatibility; ignored
    int quality = 85,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return file;

      final srcW = decoded.width;
      final srcH = decoded.height;
      if (srcW <= 0 || srcH <= 0) return file;

      // Resize to fit within target dimensions while preserving aspect ratio.
      // No cropping - just scale down and pad with background color if needed.
      final targetAspect = _targetWidth / _targetHeight;
      final srcAspect = srcW / srcH;

      int newWidth, newHeight;
      if (srcAspect > targetAspect) {
        // Wider: fit to target width
        newWidth = _targetWidth;
        newHeight = (_targetWidth / srcAspect).round();
      } else {
        // Taller: fit to target height
        newHeight = _targetHeight;
        newWidth = (_targetHeight * srcAspect).round();
      }

      // Resize preserving aspect ratio
      final resized = img.copyResize(
        decoded,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.average,
      );

      // Create canvas with target dimensions and light gray background
      final canvas = img.Image(
        width: _targetWidth,
        height: _targetHeight,
        numChannels: 3,
      );
      // Fill with light gray background (RGB: 240, 240, 240)
      img.fill(canvas, color: img.ColorRgba8(240, 240, 240, 255));

      // Center the resized image on the canvas
      final offsetX = ((_targetWidth - newWidth) / 2).round();
      final offsetY = ((_targetHeight - newHeight) / 2).round();
      img.compositeImage(canvas, resized, dstX: offsetX, dstY: offsetY);

      final dir = file.parent;
      final baseName = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'image';
      final safeBase = baseName.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
      final newPath =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${_targetWidth}x${_targetHeight}_$safeBase.jpg';
      final newFile = File(newPath);

      // Best-effort quality reduction until under [_maxBytes].
      int q = quality;
      List<int> jpgBytes = img.encodeJpg(canvas, quality: q);
      while (jpgBytes.length > _maxBytes && q > 30) {
        q -= 5;
        jpgBytes = img.encodeJpg(canvas, quality: q);
      }

      await newFile.writeAsBytes(jpgBytes, flush: true);
      return newFile;
    } catch (e) {
      // On any failure, log and fall back to original file so we don't break flows.
      debugPrint('[ImageResizeUtils] Error resizing image: $e');
      return file;
    }
  }

  /// Convenience helper: normalize to 800x800 square and apply a semi-transparent
  /// glass badge with the user's handle (e.g. "@username") at the bottom.
  /// 
  /// Uses [WatermarkConfig] for all styling and positioning parameters,
  /// allowing runtime customization and admin control.
  static Future<File> resizeAndWatermark(
    File file,
    String handle, {
    int size = 600, // kept for backwards compatibility; ignored
    int quality = 85,
  }) async {
    // Skip watermarking if disabled
    if (!WatermarkConfig.enableWatermarking) {
      return await resizeToSquareFile(file, size: size, quality: quality);
    }

    // First ensure we have a normalized base image.
    final base = await resizeToSquareFile(file, size: size, quality: quality);
    try {
      final bytes = await base.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return base;

      final canvas = img.Image.from(decoded);
      final width = canvas.width;
      final height = canvas.height;

      // Positioning based on configured padding percentages
      final paddingX = (width * WatermarkConfig.badgeHorizontalPaddingPercent).round();
      final paddingY = (height * WatermarkConfig.badgeBottomMarginPercent).round();

      // Prepare watermark text
      final text = handle.trim().isEmpty
          ? WatermarkConfig.fallbackHandle
          : '${WatermarkConfig.handlePrefix}${handle.trim()}';

      // Choose font based on configuration (currently arial14 by default)
      final font = WatermarkConfig.fontFamily == 'arial24'
          ? img.arial24
          : img.arial14;
      final int fontHeight = WatermarkConfig.fontFamily == 'arial24' ? 24 : 14;

      // Place text near the bottom-left with padding
      final textX = paddingX;
      final textY = height - paddingY - fontHeight;

      // Draw a subtle shadow for "embossed" / 3D effect
      final shadowAlpha = (WatermarkConfig.getComputedTextAlpha() * 0.7).round().clamp(0, 255);
      final shadowColor = img.ColorRgba8(0, 0, 0, shadowAlpha);
      img.drawString(
        canvas,
        text,
        font: font,
        x: textX + 2,
        y: textY + 2,
        color: shadowColor,
      );

      // Draw main text directly on top of the image (no background box)
      final mainColor = img.ColorRgba8(
        WatermarkConfig.textRed,
        WatermarkConfig.textGreen,
        WatermarkConfig.textBlue,
        WatermarkConfig.getComputedTextAlpha(),
      );
      img.drawString(
        canvas,
        text,
        font: font,
        x: textX,
        y: textY,
        color: mainColor,
      );


      // Re-encode with size cap to keep under ~50KB.
      int q = quality;
      List<int> outBytes = img.encodeJpg(canvas, quality: q);
      while (outBytes.length > _maxBytes && q > 30) {
        q -= 5;
        outBytes = img.encodeJpg(canvas, quality: q);
      }

      await base.writeAsBytes(outBytes, flush: true);
      return base;
    } catch (e) {
      debugPrint('[ImageResizeUtils] Error applying watermark: $e');
      return base;
    }
  }
}
