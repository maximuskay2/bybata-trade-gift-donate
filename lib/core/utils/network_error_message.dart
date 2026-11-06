import 'package:dio/dio.dart';

import '../errors/app_exception.dart';
import '../errors/error_handler.dart';

/// Maps API / network failures to user-facing copy for production screens.
///
/// Always use [from] (or [sanitize]) before showing an error string in UI —
/// providers often store `'Failed to load X: $e'` which embeds Dio/AppException.
abstract final class NetworkErrorMessage {
  static const String offline =
      'No internet connection. Check your network and try again.';

  static const String timeout =
      'Connection timed out. Please try again.';

  static const String serverUnavailable =
      'We can\'t reach Bybata right now. Please try again in a moment.';

  static const String generic =
      'Something went wrong. Please try again.';

  static const String listingsFallback =
      'Couldn\'t load listings right now. Pull down to try again.';

  static const String searchFallback =
      'Couldn\'t load items right now. Pull down to try again.';

  /// User-facing message from any thrown error or already-stringified message.
  static String from(Object? error, {String fallback = generic}) {
    if (error == null) return fallback;

    if (error is AppException) return error.userMessage;

    if (error is DioException) {
      return fromDio(error, fallback: fallback);
    }

    if (error is String) {
      return sanitize(error, fallback: fallback);
    }

    // Typed Dio/network errors → friendly AppException copy.
    final mapped = ErrorHandler.toAppException(error);
    if (mapped.type != AppExceptionType.unknown) {
      return mapped.userMessage;
    }

    // Wrappers like Exception('Failed to load X: DioException…') → sanitize.
    return sanitize('$error', fallback: fallback);
  }

  /// Sanitize a message that may already contain DioException / AppException text.
  static String sanitize(String? raw, {String fallback = generic}) {
    if (raw == null) return fallback;
    var text = raw.trim();
    if (text.isEmpty) return fallback;

    if (text.startsWith('Exception: ')) {
      text = text.substring('Exception: '.length).trim();
    }

    // Prefer the human message embedded in AppException(... message: …).
    final embedded = _extractAppExceptionUserMessage(text);
    if (embedded != null && embedded.isNotEmpty) {
      return embedded;
    }

    if (!_stringLooksTechnical(text) && !_looksLikeFailedLoadWrapper(text)) {
      return text;
    }

    if (_indicatesTimeout(text)) return timeout;
    if (_indicatesOffline(text)) return offline;
    if (_indicatesServer(text)) return serverUnavailable;
    if (_indicatesUnauthorized(text)) {
      return 'Session expired. Please log in again.';
    }

    // "Failed to load notifications: …" with only technical suffix → friendly.
    if (_looksLikeFailedLoadWrapper(text)) {
      return fallback == generic
          ? 'Couldn\'t load this right now. Please try again.'
          : fallback;
    }

    return fallback;
  }

  static String fromDio(DioException error, {String fallback = generic}) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.trim().isNotEmpty) {
        return sanitize(msg.trim(), fallback: fallback);
      }
      if (msg is List && msg.isNotEmpty) {
        return sanitize(msg.first.toString(), fallback: fallback);
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return timeout;
      case DioExceptionType.connectionError:
        return offline;
      case DioExceptionType.cancel:
        return fallback;
      case DioExceptionType.badResponse:
        if (statusCode == 401) {
          return 'Please sign in again to continue.';
        }
        if (statusCode == 403) {
          return 'You don\'t have permission to view this.';
        }
        if (statusCode == 404) {
          return 'Nothing found. Try a different search.';
        }
        if (statusCode == 429) {
          return 'Too many requests. Please wait and try again.';
        }
        if (statusCode != null && statusCode >= 500) {
          return serverUnavailable;
        }
        return generic;
      case DioExceptionType.badCertificate:
        return 'Secure connection failed. Please try again.';
      case DioExceptionType.unknown:
        break;
    }

    final err = error.error?.toString() ?? '';
    if (_indicatesOffline(err) || _indicatesOffline(error.message ?? '')) {
      return offline;
    }
    if (_indicatesTimeout(err) || _indicatesTimeout(error.message ?? '')) {
      return timeout;
    }
    return fallback;
  }

  static String forListingLoad(Object? error) =>
      from(error, fallback: listingsFallback);

  static String forSearchLoad(Object? error) =>
      from(error, fallback: searchFallback);

  /// Short title for full-screen / section error UIs.
  static String titleFrom(Object? error) {
    final text = error is String ? error : '$error';
    if (isOffline(error) || messageIndicatesOffline(text) || _indicatesOffline(text)) {
      return "You're offline";
    }
    if (isTimeout(error) || _indicatesTimeout(text)) {
      return 'Connection timed out';
    }
    if (_indicatesServer(text)) {
      return 'Service unavailable';
    }
    return "Couldn't load this";
  }

  static bool isOffline(Object? error) {
    if (error is AppException) {
      return error.type == AppExceptionType.network;
    }
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError;
    }
    final raw = error?.toString().toLowerCase() ?? '';
    return _indicatesOffline(raw);
  }

  static bool isTimeout(Object? error) {
    if (error is AppException) {
      return error.type == AppExceptionType.timeout;
    }
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout;
    }
    return _indicatesTimeout(error?.toString() ?? '');
  }

  static bool messageIndicatesOffline(String? message) {
    if (message == null || message.isEmpty) return false;
    return _indicatesOffline(message);
  }

  static bool messageIndicatesTimeout(String? message) {
    if (message == null || message.isEmpty) return false;
    return _indicatesTimeout(message);
  }

  /// @nodoc — kept only for older call-site patterns; prefer [sanitize].
  static bool looksLikeRawTechnical(String raw) => _stringLooksTechnical(raw);

  static bool _stringLooksTechnical(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('dioexception') ||
        lower.contains('appexception') ||
        lower.contains('appexceptiontype') ||
        lower.contains('socketexception') ||
        lower.contains('statuscode: null') ||
        lower.contains('failed: null') ||
        lower.contains('connection timeout') ||
        lower.contains('receive timeout') ||
        lower.contains('send timeout') ||
        lower.contains('xmlhttprequest error') ||
        lower.contains('handshakeexception') ||
        lower.contains('public trade list failed') ||
        lower.contains('public gift list failed') ||
        lower.contains('public campaign list failed') ||
        lower.contains('public community list failed') ||
        (lower.startsWith('failed to load') &&
            (lower.contains('exception') || lower.contains('error:')));
  }

  static bool _looksLikeFailedLoadWrapper(String raw) {
    final lower = raw.toLowerCase();
    return lower.startsWith('failed to load') ||
        lower.startsWith('failed to initialize') ||
        lower.startsWith('failed to refresh') ||
        lower.startsWith('failed to connect');
  }

  static bool _indicatesTimeout(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('connection timed out');
  }

  static bool _indicatesOffline(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('no internet') ||
        lower.contains('check your network') ||
        lower.contains('connection error') ||
        lower.contains('socketexception') ||
        lower.contains('network is unreachable') ||
        lower.contains('failed host lookup') ||
        lower.contains('network unreachable') ||
        lower.contains('cannot reach the server') ||
        lower.contains('not connected');
  }

  static bool _indicatesServer(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('service unavailable') ||
        lower.contains('server error') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('500');
  }

  static bool _indicatesUnauthorized(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('unauthorized') ||
        lower.contains('401') ||
        lower.contains('session expired') ||
        lower.contains('jwt expired');
  }

  /// Pulls `message: …` from `AppException(... message: The connection timed out. …)`.
  static String? _extractAppExceptionUserMessage(String text) {
    if (!text.toLowerCase().contains('appexception')) return null;
    final match = RegExp(
      r'message:\s*(.+?)\)\s*$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    final msg = match?.group(1)?.trim();
    if (msg == null || msg.isEmpty) return null;
    if (_stringLooksTechnical(msg) && !_indicatesTimeout(msg) && !_indicatesOffline(msg)) {
      return null;
    }
    return msg;
  }
}
