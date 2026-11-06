/// Decides whether an intent response may replace the keyword layout.
class IntentApplyGate {
  static const int cutoffMs = 1800;
  static const double minConfidence = 0.6;

  static bool shouldApply({
    required bool flagEnabled,
    required int requestGeneration,
    required int currentGeneration,
    required int elapsedMs,
    required double confidence,
  }) {
    if (!flagEnabled) return false;
    if (requestGeneration != currentGeneration) return false;
    if (elapsedMs > cutoffMs) return false;
    if (confidence < minConfidence) return false;
    return true;
  }
}
