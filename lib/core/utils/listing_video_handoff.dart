import 'package:flutter/foundation.dart';

/// Coordinates pausing feed inline videos when opening listing detail screens.
abstract final class ListingVideoHandoff {
  static final Map<String, VoidCallback> _pauseCallbacks = {};
  static final Map<String, VoidCallback> _pauseForDetailCallbacks = {};
  static final Map<String, VoidCallback> _resumeCallbacks = {};
  static String? _detailNavigationVideoKey;

  static void register(
    String videoKey, {
    required VoidCallback pause,
    required VoidCallback pauseForDetail,
  }) {
    final key = videoKey.trim();
    if (key.isEmpty) return;
    _pauseCallbacks[key] = pause;
    _pauseForDetailCallbacks[key] = pauseForDetail;
  }

  static void unregister(String videoKey) {
    final key = videoKey.trim();
    if (key.isEmpty) return;
    _pauseCallbacks.remove(key);
    _pauseForDetailCallbacks.remove(key);
    _resumeCallbacks.remove(key);
    if (_detailNavigationVideoKey == key) {
      _detailNavigationVideoKey = null;
    }
  }

  /// Pause other feed videos and mark the tapped listing for detail navigation.
  static void prepareDetailNavigation(String videoKey) {
    final key = videoKey.trim();
    if (key.isEmpty) return;
    _detailNavigationVideoKey = key;

    for (final entry in _pauseCallbacks.entries.toList()) {
      if (entry.key == key) {
        _pauseForDetailCallbacks[key]?.call();
      } else {
        entry.value();
      }
    }
  }

  static void pauseAllExcept(String videoKey) {
    final key = videoKey.trim();
    for (final entry in _pauseCallbacks.entries) {
      if (entry.key != key) entry.value();
    }
  }

  static void registerResume(String videoKey, VoidCallback resume) {
    final key = videoKey.trim();
    if (key.isEmpty) return;
    _resumeCallbacks[key] = resume;
  }

  /// Resume the feed inline player after the detail route closes.
  static void onDetailRouteClosed() {
    final key = _detailNavigationVideoKey;
    _detailNavigationVideoKey = null;
    if (key == null || key.isEmpty) return;
    _resumeCallbacks[key]?.call();
  }

  /// @deprecated Use [onDetailRouteClosed]. Kept for callers that still invoke it.
  static void notifyDetailPlaybackEnded(String videoKey) {
    onDetailRouteClosed();
  }

  /// @deprecated Feed players no longer stash controllers. Resumes inline playback.
  static void releaseUnclaimed() {
    onDetailRouteClosed();
  }
}
