import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../constants/listing_media_constants.dart';

/// Forces listing photos through a locked 16:10 crop matching the timeline feed.
class ImageCropUtils {
  ImageCropUtils._();

  /// Interactive crop locked to the timeline feed aspect (16:10).
  static Future<File?> cropToFeedWidescreen(
    BuildContext context,
    File source,
  ) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: source.path,
        aspectRatio: const CropAspectRatio(
          ratioX: 16,
          ratioY: 10,
        ),
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop for feed',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop for feed',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );
      if (cropped == null) return null;
      return File(cropped.path);
    } catch (e) {
      debugPrint('[ImageCropUtils] crop failed: $e');
      return null;
    }
  }

  /// Backward-compatible alias — now crops to 16:10 feed aspect.
  static Future<File?> cropToPortraitFourFive(
    BuildContext context,
    File source,
  ) =>
      cropToFeedWidescreen(context, source);

  static double get feedAspect => ListingMediaConstants.feedAspectRatio;

  /// @deprecated Use [feedAspect].
  static double get portraitAspect => feedAspect;
}
