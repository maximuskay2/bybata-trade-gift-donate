import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Shared Hive JSON disk cache for offline-first feature data.
///
/// Keys are scoped as `u:{userId}:{key}` (or global when [userId] is null).
abstract final class OfflineJsonCache {
  static Future<Box<String>> openBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<String>(boxName);
    }
    return Hive.openBox<String>(boxName);
  }

  static String scopedKey(String? userId, String key) {
    if (userId == null || userId.isEmpty) return key;
    return 'u:$userId:$key';
  }

  static Future<void> putJson(
    String boxName,
    String? userId,
    String key,
    Object value,
  ) async {
    try {
      final box = await openBox(boxName);
      await box.put(scopedKey(userId, key), jsonEncode(value));
    } catch (_) {}
  }

  static Future<Object?> getJson(
    String boxName,
    String? userId,
    String key,
  ) async {
    try {
      final box = await openBox(boxName);
      final raw = box.get(scopedKey(userId, key));
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getMap(
    String boxName,
    String? userId,
    String key,
  ) async {
    final v = await getJson(boxName, userId, key);
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static Future<List<Map<String, dynamic>>> getList(
    String boxName,
    String? userId,
    String key,
  ) async {
    final v = await getJson(boxName, userId, key);
    if (v is! List) return const [];
    return v
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> putList(
    String boxName,
    String? userId,
    String key,
    List<Map<String, dynamic>> items,
  ) =>
      putJson(boxName, userId, key, items);

  static Future<void> putMap(
    String boxName,
    String? userId,
    String key,
    Map<String, dynamic> map,
  ) =>
      putJson(boxName, userId, key, map);

  static Future<void> clearUser(String boxName, String userId) async {
    if (userId.isEmpty) return;
    try {
      final box = await openBox(boxName);
      final prefix = 'u:$userId:';
      final keys = box.keys
          .map((k) => k.toString())
          .where((k) => k.startsWith(prefix))
          .toList();
      for (final k in keys) {
        await box.delete(k);
      }
    } catch (_) {}
  }
}
