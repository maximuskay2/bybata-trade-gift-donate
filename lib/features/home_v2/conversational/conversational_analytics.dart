import '../../../core/utils/app_logger.dart';

/// Lightweight analytics hooks for conversational home (AppLogger until Firebase events wired).
abstract final class ConversationalAnalytics {
  static void searchSubmitted(String query) {
    AppLogger.debug('[analytics] conversational_search_submitted query="$query"');
  }

  static void resultTap({
    required String module,
    required String listingId,
  }) {
    AppLogger.debug(
      '[analytics] conversational_result_tap module=$module id=$listingId',
    );
  }

  static void backupSearchOpened() {
    AppLogger.debug('[analytics] conversational_backup_search_opened');
  }

  static void radiusExpanded({double? radiusKm}) {
    AppLogger.debug(
      '[analytics] conversational_radius_expanded radiusKm=${radiusKm ?? "unknown"}',
    );
  }

  static void aiIntentShown({
    required String label,
    required double confidence,
    required int results,
  }) {
    AppLogger.debug(
      '[analytics] ai_intent_shown label="$label" confidence=$confidence results=$results',
    );
  }

  static void aiIntentCleared() {
    AppLogger.debug('[analytics] ai_intent_cleared');
  }

  static void aiIntentFallback({required String reason}) {
    AppLogger.debug('[analytics] ai_intent_fallback reason=$reason');
  }

  static void aiIntentSlotTap({
    required String module,
    required String listingId,
    required String size,
  }) {
    AppLogger.debug(
      '[analytics] ai_intent_slot_tap module=$module id=$listingId size=$size',
    );
  }

  static void aiIntentConversion({
    required String kind,
    required String listingId,
  }) {
    AppLogger.debug(
      '[analytics] ai_intent_conversion kind=$kind id=$listingId',
    );
  }

  static void messageOwnerTap({
    required String module,
    required String listingId,
  }) {
    AppLogger.debug(
      '[analytics] conversational_message_owner module=$module id=$listingId',
    );
  }
}
