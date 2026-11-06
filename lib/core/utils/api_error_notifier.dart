import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'network_error_message.dart';

class ApiErrorNotifier {
  /// Previously this helper always surfaced API errors via a global
  /// snackbar. To reduce noise and avoid distracting users with generic
  /// backend issues (e.g. rate limits, transient errors), we now suppress
  /// the global toast entirely and only log in debug builds. Screens that
  /// care about specific failures should catch the error and present
  /// tailored UI.
  static void show(DioException error) {
    final message = _messageFrom(error);
    if (message == null || message.isEmpty) return;

    if (kDebugMode) {
      // ignore: avoid_print
      print('[API ERROR] $message');
    }

    // No global snackbar by default; keep UX quiet on background failures.
    // If you need to notify the user, call AppToast.showGlobal from the
    // feature/widget that initiated the request.
  }

  static String? _messageFrom(DioException error) {
    if (error.type == DioExceptionType.cancel) return null;
    return NetworkErrorMessage.fromDio(error);
  }
}
