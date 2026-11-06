import 'env_config.dart';

/// Feature Flags Configuration
/// 
/// Controls gradual rollout of new features.
/// Default to false in production, true in development/staging.
class FeatureFlags {
  static bool? _enableUnifiedFeed;
  static bool? _enableOfferAskFlow;
  static bool? _enableInteractionEndpoints;
  static bool? _enableConversationalFeed;
  static bool? _enableAiSearch;

  /// Conversational bento home (`CONVERSATIONAL_FEED_ENABLED`).
  static Future<bool> get enableConversationalFeed async {
    _enableConversationalFeed ??= await _parseBoolean(
      'CONVERSATIONAL_FEED_ENABLED',
      defaultValue: true,
    );
    return _enableConversationalFeed!;
  }

  /// Test hook. Null uses the compile-time flag.
  static bool? debugOverrideAiSearch;

  static const String _aiSearchDefine = String.fromEnvironment(
    'ENABLE_AI_SEARCH',
    defaultValue: '',
  );

  /// Call `/v1/search/intent` on submit. Off keeps today's keyword layout.
  static Future<bool> get enableAiSearch async {
    if (debugOverrideAiSearch != null) return debugOverrideAiSearch!;
    if (_aiSearchDefine == 'true') return true;
    if (_aiSearchDefine == 'false') return false;
    _enableAiSearch ??= await _parseBoolean(
      'ENABLE_AI_SEARCH',
      defaultValue: true,
    );
    return _enableAiSearch!;
  }

  /// Check if unified feed feature is enabled
  static Future<bool> get enableUnifiedFeed async {
    _enableUnifiedFeed ??= await _parseBoolean(
      'ENABLE_UNIFIED_FEED',
      defaultValue: true, // Default enabled for now
    );
    return _enableUnifiedFeed!;
  }

  /// Check if offer/ask flow feature is enabled
  static Future<bool> get enableOfferAskFlow async {
    _enableOfferAskFlow ??= await _parseBoolean(
      'ENABLE_OFFER_ASK_FLOW',
      defaultValue: true, // Default enabled for now
    );
    return _enableOfferAskFlow!;
  }

  /// Check if interaction endpoints are enabled
  static Future<bool> get enableInteractionEndpoints async {
    _enableInteractionEndpoints ??= await _parseBoolean(
      'ENABLE_INTERACTION_ENDPOINTS',
      defaultValue: true, // Default enabled for now
    );
    return _enableInteractionEndpoints!;
  }

  static Future<bool> _parseBoolean(String key, {required bool defaultValue}) async {
    // For now, return default value since we don't have env variable storage
    // In production, this would read from SharedPreferences or environment config
    return defaultValue;
  }

  /// Reset cached values (useful for testing)
  static void reset() {
    _enableUnifiedFeed = null;
    _enableOfferAskFlow = null;
    _enableInteractionEndpoints = null;
    _enableConversationalFeed = null;
    _enableAiSearch = null;
    debugOverrideAiSearch = null;
  }
}
