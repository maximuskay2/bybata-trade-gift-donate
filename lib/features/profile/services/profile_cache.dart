import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/user_profile.dart';

/// Lightweight cache for the current user's profile, backed by Hive.
///
/// We store a single entry keyed as 'me' in the 'user_profile_cache' box.
class ProfileCache {
  static const String _boxName = 'user_profile_cache';
  static const String _currentKey = 'me';

  static Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<String>(_boxName);
    }
    return await Hive.openBox<String>(_boxName);
  }

  /// Load the cached current user's profile if available.
  static Future<UserProfile?> loadCurrent() async {
    try {
      final box = await _openBox();
      final raw = box.get(_currentKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Save/overwrite the cached current user's profile.
  static Future<void> saveCurrent(UserProfile profile) async {
    try {
      final box = await _openBox();
      final jsonStr = jsonEncode(profile.toJson());
      await box.put(_currentKey, jsonStr);
    } catch (_) {
      // Ignore cache failures; profile fetching still works via network.
    }
  }

  static Future<void> clear() async {
    try {
      final box = await _openBox();
      await box.delete(_currentKey);
    } catch (_) {}
  }
}
