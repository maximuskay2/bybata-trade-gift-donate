import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import '../widgets/app_toast.dart';

class UiUtils {
  /// Handle an error in a user-friendly way.
  ///
  /// Previously this showed a global snackbar for every network/server
  /// exception. To avoid spamming users with generic error toasts, we now
  /// handle errors silently in production and only log details in debug
  /// builds. Screens that need to surface specific issues should handle
  /// errors locally instead of relying on this global hook.
  static void handleError(Object error) {
    final appException = ErrorHandler.toAppException(error);

    // In debug, log the message to help with troubleshooting.
    if (kDebugMode) {
      // ignore: avoid_print
      print('[UI ERROR] ${appException.userMessage}');
    }

    // No global snackbar in production to avoid bothering users with
    // generic infrastructure or rate-limit issues.
    // If you need a user-facing message, handle it explicitly in the
    // calling widget using AppToast or inline UI.
  }
}
