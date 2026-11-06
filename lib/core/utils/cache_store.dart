import 'package:flutter/foundation.dart';

/// Simple in-memory cache with per-store TTL, for use inside services/providers.
///
/// This is intentionally small and framework-agnostic so it can be reused
/// across features (trades, profile activity, etc.).
class CacheEntry<V> {
  final V value;
  final DateTime fetchedAt;

  CacheEntry({required this.value, required this.fetchedAt});

  bool isFresh(Duration ttl) {
    return DateTime.now().difference(fetchedAt) < ttl;
  }
}

class CacheStore<K, V> {
  final Duration ttl;
  final _items = <K, CacheEntry<V>>{};

  CacheStore({required this.ttl});

  /// Returns a cached value only if it is still fresh; otherwise null.
  V? getIfFresh(K key) {
    final entry = _items[key];
    if (entry == null) return null;
    if (!entry.isFresh(ttl)) {
      _items.remove(key);
      return null;
    }
    return entry.value;
  }

  /// Store a value in the cache.
  void set(K key, V value) {
    _items[key] = CacheEntry<V>(value: value, fetchedAt: DateTime.now());
  }

  /// Manually invalidate either a single key or the entire cache.
  void invalidate([K? key]) {
    if (key == null) {
      _items.clear();
    } else {
      _items.remove(key);
    }
  }

  /// For debugging / metrics.
  @visibleForTesting
  Map<K, CacheEntry<V>> get debugItems => _items;
}
