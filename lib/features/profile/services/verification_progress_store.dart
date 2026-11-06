import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// Local backup of verification progress (API remains source of truth).
class VerificationProgressStore {
  static String _key(String userId) => 'verification_progress_$userId';

  static Future<void> save({
    required String userId,
    required VerificationStatus status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId),
      jsonEncode({
        'status': status.status.toString().split('.').last,
        'completedVerifications': status.completedVerifications
            .map((t) => t.toString().split('.').last)
            .toList(),
        'rejectionReason': status.rejectionReason,
        'savedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<VerificationStatus?> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return VerificationStatus.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }
}
