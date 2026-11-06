import 'dart:async';

import 'package:flutter/foundation.dart';

import 'listing_video_visibility.dart';

/// Caps decoders, init concurrency, and picks one autoplay winner by visibility.
abstract final class ListingVideoCoordinator {
  static const int maxDecoders = 3;
  static const int maxConcurrentInits = 3;

  static int _initInFlight = 0;
  static String? _autoplayKey;
  static final Map<String, double> _visibility = {};
  static final Set<String> _activeDecoders = {};
  static final Map<String, VoidCallback> _decoderWaiters = {};
  static final Map<String, VoidCallback> _autoplayWon = {};
  static final Map<String, VoidCallback> _autoplayLost = {};

  static Future<void> acquireInitSlot() async {
    while (_initInFlight >= maxConcurrentInits) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    _initInFlight++;
  }

  static void releaseInitSlot() {
    if (_initInFlight > 0) _initInFlight--;
  }

  static bool tryAcquireDecoder(String videoKey) {
    final key = videoKey.trim();
    if (key.isEmpty) return false;
    if (_activeDecoders.contains(key)) return true;
    if (_activeDecoders.length >= maxDecoders) return false;
    _activeDecoders.add(key);
    return true;
  }

  static void releaseDecoder(String videoKey) {
    final key = videoKey.trim();
    if (!_activeDecoders.remove(key)) return;
    _promoteDecoderWaiter();
  }

  static void registerDecoderWaiter(String videoKey, VoidCallback onSlot) {
    final key = videoKey.trim();
    if (key.isEmpty) return;
    _decoderWaiters[key] = onSlot;
    if (_activeDecoders.length < maxDecoders) {
      _promoteDecoderWaiter(forKey: key);
    }
  }

  static void unregisterDecoderWaiter(String videoKey) {
    _decoderWaiters.remove(videoKey.trim());
  }

  static void _promoteDecoderWaiter({String? forKey}) {
    if (_activeDecoders.length >= maxDecoders) return;
    if (forKey != null) {
      final waiter = _decoderWaiters.remove(forKey);
      if (waiter != null && tryAcquireDecoder(forKey)) {
        waiter();
      }
      return;
    }
    for (final key in _decoderWaiters.keys.toList()) {
      if (_activeDecoders.length >= maxDecoders) break;
      final waiter = _decoderWaiters.remove(key);
      if (waiter != null && tryAcquireDecoder(key)) {
        waiter();
      }
    }
  }

  static void reportVisibility(String videoKey, double visibleFraction) {
    final key = videoKey.trim();
    if (key.isEmpty) return;

    if (visibleFraction <= 0) {
      _visibility.remove(key);
    } else {
      _visibility[key] = visibleFraction;
    }
    _electAutoplayWinner();
  }

  static void clearVisibility(String videoKey) {
    final key = videoKey.trim();
    _visibility.remove(key);
    if (_autoplayKey == key) {
      _autoplayKey = null;
      _electAutoplayWinner();
    }
  }

  static bool isAutoplayWinner(String videoKey) =>
      _autoplayKey == videoKey.trim();

  static bool shouldPlay(String videoKey) {
    final key = videoKey.trim();
    final fraction = _visibility[key] ?? 0;
    return isAutoplayWinner(key) &&
        fraction >= ListingVideoVisibility.playThreshold;
  }

  static void registerAutoplayCallbacks({
    required String videoKey,
    required VoidCallback onWon,
    required VoidCallback onLost,
  }) {
    final key = videoKey.trim();
    if (key.isEmpty) return;
    _autoplayWon[key] = onWon;
    _autoplayLost[key] = onLost;
  }

  static void unregisterAutoplayCallbacks(String videoKey) {
    final key = videoKey.trim();
    _autoplayWon.remove(key);
    _autoplayLost.remove(key);
  }

  static void _electAutoplayWinner() {
    String? bestKey;
    var bestScore = ListingVideoVisibility.playThreshold;

    for (final entry in _visibility.entries) {
      if (entry.value >= ListingVideoVisibility.playThreshold &&
          entry.value > bestScore) {
        bestScore = entry.value;
        bestKey = entry.key;
      }
    }

    if (bestKey == _autoplayKey) return;

    final previous = _autoplayKey;
    _autoplayKey = bestKey;

    if (previous != null && previous != bestKey) {
      _autoplayLost[previous]?.call();
    }
    if (bestKey != null && bestKey != previous) {
      _autoplayWon[bestKey]?.call();
    }
  }

  /// Legacy helper — defers to visibility winner when feed inline.
  static bool claimAutoplay(String videoKey) {
    final key = videoKey.trim();
    if (key.isEmpty) return false;
    if (_autoplayKey == null) {
      _autoplayKey = key;
      return true;
    }
    return _autoplayKey == key;
  }

  static void releaseAutoplay(String videoKey) {
    final key = videoKey.trim();
    if (_autoplayKey != key) return;
    _autoplayKey = null;
    _electAutoplayWinner();
  }
}
