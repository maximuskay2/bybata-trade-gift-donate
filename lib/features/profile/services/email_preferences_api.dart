import 'package:bybata/core/api/api_client.dart';
import 'package:bybata/core/config/env_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API for managing email preferences (weekly report, marketing, etc.).
class EmailPreferencesApi {
  final ApiClient _client =
      ApiClient(EnvConfig.defaultBaseUrl, const FlutterSecureStorage());

  static const String _path = '/v1/email/preferences';

  /// Fetches the current user's email preferences.
  /// Returns defaults when no preference record exists.
  Future<EmailPreferences> getPreferences() async {
    final response = await _client.get(_path);
    final data = response.data as Map<String, dynamic>? ?? {};
    return EmailPreferences(
      transactional: data['transactional'] as bool? ?? true,
      marketing: data['marketing'] as bool? ?? true,
      digest: data['digest'] as bool? ?? true,
      weeklyReport: data['weeklyReport'] as bool? ?? false,
    );
  }

  /// Updates the user's email preferences.
  Future<EmailPreferences> updatePreferences(EmailPreferences prefs) async {
    final response = await _client.put(
      _path,
      data: {
        'transactional': prefs.transactional,
        'marketing': prefs.marketing,
        'digest': prefs.digest,
        'weeklyReport': prefs.weeklyReport,
      },
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    return EmailPreferences(
      transactional: data['transactional'] as bool? ?? true,
      marketing: data['marketing'] as bool? ?? true,
      digest: data['digest'] as bool? ?? true,
      weeklyReport: data['weeklyReport'] as bool? ?? false,
    );
  }
}

class EmailPreferences {
  final bool transactional;
  final bool marketing;
  final bool digest;
  final bool weeklyReport;

  const EmailPreferences({
    this.transactional = true,
    this.marketing = true,
    this.digest = true,
    this.weeklyReport = false,
  });

  EmailPreferences copyWith({
    bool? transactional,
    bool? marketing,
    bool? digest,
    bool? weeklyReport,
  }) {
    return EmailPreferences(
      transactional: transactional ?? this.transactional,
      marketing: marketing ?? this.marketing,
      digest: digest ?? this.digest,
      weeklyReport: weeklyReport ?? this.weeklyReport,
    );
  }
}
