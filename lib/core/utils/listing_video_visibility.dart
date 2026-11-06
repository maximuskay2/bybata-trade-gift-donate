/// Visibility thresholds for inline feed listing videos.
abstract final class ListingVideoVisibility {
  static const double playThreshold = 0.6;
  static const double pauseThreshold = 0.4;
  /// Dispose decoder when almost fully off-screen to free MediaCodec slots.
  static const double releaseThreshold = 0.05;
}
