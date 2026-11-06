import 'dart:collection';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Centralised logger that:
///   1. Always emits to `dart:developer.log()` so messages reach `os_log`
///      and are visible in Mac Console.app / `idevicesyslog` even on
///      profile/release builds (regular `print` is swallowed by our zone).
///   2. Mirrors entries into a bounded in-memory ring buffer, surfaced via
///      [AppLogger.snapshot] for the in-app diagnostics screen.
///   3. Forwards errors to Firebase Crashlytics in non-debug builds.
class AppLogger {
  AppLogger._();

  static const int _maxBufferEntries = 500;
  static const String _tag = 'Bybata';
  static final Queue<LogEntry> _buffer = Queue<LogEntry>();
  static final List<VoidCallback> _listeners = <VoidCallback>[];

  /// Read-only snapshot of the in-memory log buffer (oldest first).
  static List<LogEntry> snapshot() => List<LogEntry>.unmodifiable(_buffer);

  /// Subscribe to buffer mutations (used by the diagnostics screen).
  static void addListener(VoidCallback cb) => _listeners.add(cb);
  static void removeListener(VoidCallback cb) => _listeners.remove(cb);

  /// Clear the in-memory buffer. Crashlytics history is unaffected.
  static void clear() {
    _buffer.clear();
    _notify();
  }

  static void debug(String message) {
    _record(LogLevel.debug, message);
  }

  static void info(String message) {
    _record(LogLevel.info, message);
  }

  static void warn(String message, {Object? error, StackTrace? stack}) {
    _record(LogLevel.warn, message, error: error, stack: stack);
  }

  static Future<void> logError(
    Object error,
    StackTrace? stack, {
    String? hint,
  }) async {
    final message = hint == null ? error.toString() : '$hint :: $error';
    _record(LogLevel.error, message, error: error, stack: stack);

    if (kDebugMode) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: hint,
        printDetails: false,
      );
    } catch (_) {
      // Never let logging itself crash the app.
    }
  }

  static void _record(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stack,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error,
      stack: stack,
    );

    _buffer.addLast(entry);
    while (_buffer.length > _maxBufferEntries) {
      _buffer.removeFirst();
    }

    // Always emit through dart:developer so os_log / Console.app / Xcode
    // capture the line on every build mode (debug, profile, release).
    developer.log(
      message,
      name: '$_tag.${level.name}',
      level: level._severity,
      error: error,
      stackTrace: stack,
    );

    _notify();
  }

  static void _notify() {
    for (final cb in List<VoidCallback>.from(_listeners)) {
      try {
        cb();
      } catch (_) {}
    }
  }
}

enum LogLevel { debug, info, warn, error }

extension on LogLevel {
  int get _severity {
    switch (this) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warn:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stack;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stack,
  });

  /// Plain-text format suitable for share sheets / clipboard.
  String format() {
    final buf = StringBuffer()
      ..write(timestamp.toIso8601String())
      ..write(' [')
      ..write(level.name.toUpperCase())
      ..write('] ')
      ..write(message);
    if (stack != null) {
      buf
        ..write('\n')
        ..write(stack);
    }
    return buf.toString();
  }
}
