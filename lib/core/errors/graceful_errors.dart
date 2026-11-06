import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/common/widgets/state_components.dart';
import '../utils/app_logger.dart';
import '../utils/network_error_message.dart';
import 'app_exception.dart';
import 'error_handler.dart';

/// Production-safe error messaging and UI helpers.
///
/// Never surface raw exception text to users in release builds.
abstract final class GracefulErrors {
  static const String defaultTitle = "Couldn't load this";
  static const String defaultMessage =
      'Something went wrong. Please try again in a moment.';

  /// User-facing message (never raw stack traces / DioException text).
  static String userMessage(Object error) {
    return NetworkErrorMessage.from(error);
  }

  static ErrorStateType visualType(Object error) {
    switch (ErrorHandler.toAppException(error).type) {
      case AppExceptionType.network:
      case AppExceptionType.timeout:
        return ErrorStateType.network;
      case AppExceptionType.server:
      case AppExceptionType.serviceUnavailable:
        return ErrorStateType.server;
      case AppExceptionType.unauthorized:
        return ErrorStateType.authentication;
      case AppExceptionType.notFound:
      case AppExceptionType.badRequest:
        return ErrorStateType.generic;
      case AppExceptionType.unknown:
        return ErrorStateType.generic;
    }
  }

  static void record(
    Object error,
    StackTrace? stack, {
    String? hint,
  }) {
    AppLogger.logError(error, stack, hint: hint);
  }

  /// Full-screen recoverable error (profile, lists, tabs).
  static Widget screen({
    required Object error,
    String title = defaultTitle,
    String? message,
    VoidCallback? onRetry,
    VoidCallback? onGoBack,
    String retryLabel = 'Try again',
  }) {
    return _ScreenErrorShell(
      child: ErrorState(
        title: title,
        message: message ?? userMessage(error),
        type: visualType(error),
        actionText: onRetry != null ? retryLabel : null,
        onRetry: onRetry,
        showDetails: kDebugMode,
        errorDetails: kDebugMode ? '$error' : null,
      ),
      onGoBack: onGoBack,
    );
  }

  /// Inline section error (activity tab, achievements, etc.).
  static Widget inline({
    required Object error,
    String title = 'Unable to load',
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: ErrorState(
        title: title,
        message: userMessage(error),
        type: visualType(error),
        actionText: onRetry != null ? 'Try again' : null,
        onRetry: onRetry,
        showDetails: kDebugMode,
        errorDetails: kDebugMode ? '$error' : null,
      ),
    );
  }

  /// Fallback when a widget subtree fails to build (no retry context).
  static Widget buildFallback({FlutterErrorDetails? details}) {
    final error = details?.exception;
    final message = error != null
        ? userMessage(error)
        : defaultMessage;

    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sentiment_dissatisfied_outlined,
                  size: 56,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (kDebugMode && details != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${details.exception}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Go back and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Run async work; returns null on failure after logging.
  static Future<T?> guard<T>(
    Future<T> Function() action, {
    String? hint,
    void Function(Object error)? onError,
  }) async {
    try {
      return await action();
    } catch (e, st) {
      record(e, st, hint: hint);
      onError?.call(e);
      return null;
    }
  }
}

class _ScreenErrorShell extends StatelessWidget {
  const _ScreenErrorShell({
    required this.child,
    this.onGoBack,
  });

  final Widget child;
  final VoidCallback? onGoBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (onGoBack != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onGoBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go back'),
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
