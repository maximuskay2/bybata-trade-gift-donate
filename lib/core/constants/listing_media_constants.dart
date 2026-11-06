import '../utils/video_processing_utils.dart';

/// Shared listing media layout and upload guidance (trades, gifts, donations).
class ListingMediaConstants {
  ListingMediaConstants._();

  /// Feed card / upload aspect for the timeline browse feeds (16:10 widescreen).
  static const double feedAspectRatio = 16 / 10;

  /// @deprecated Use [feedAspectRatio]. Kept for older portrait-oriented screens.
  static const double portraitAspectRatio = feedAspectRatio;

  /// Target max dimensions after crop (~1600×1000).
  static const int targetWidth = 1600;
  static const int targetHeight = 1000;

  /// Default photo count cap in create / edit flows.
  static const int maxPhotosPerListing = 5;

  /// Target JPEG size after compression (see [ImageResizeUtils]).
  static const int targetImageMaxBytes = 100 * 1024;

  static const String aspectRatioLabel = '16:10 widescreen';
  static String get recommendedDimensionsLabel =>
      '$targetWidth×$targetHeight px';

  static String get maxVideoDurationLabel {
    final seconds = VideoProcessingUtils.maxDuration.inSeconds;
    if (seconds >= 60 && seconds % 60 == 0) {
      return '${seconds ~/ 60} minute${seconds == 60 ? '' : 's'} max';
    }
    return '$seconds seconds max';
  }

  static String get targetImageSizeLabel {
    final kb = (targetImageMaxBytes / 1024).round();
    return '~$kb KB each after upload (auto-compressed)';
  }

  /// Short lines shown under the media picker for all listing types.
  static List<String> uploadGuidance({int maxPhotos = maxPhotosPerListing}) => [
        'Photos are cropped to $aspectRatioLabel for the feed — ideal $recommendedDimensionsLabel.',
        'Photos: up to $maxPhotos JPG/PNG images. $targetImageSizeLabel',
        'Video: one clip, $maxVideoDurationLabel. Shown as $aspectRatioLabel in the feed.',
        'Choose either photos or video — not both on the same listing.',
      ];
}
