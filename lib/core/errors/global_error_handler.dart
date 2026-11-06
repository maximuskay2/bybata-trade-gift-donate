import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../navigation/guarded_navigator.dart';
import '../navigation/main_navigation.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/app_messenger.dart';
import '../widgets/app_toast.dart';
import 'graceful_errors.dart';

/// Central production error policy: log everything, never replace the whole app
/// for recoverable framework noise.
abstract final class GlobalErrorHandler {
  static DateTime? _lastTransientNotice;

  /// Errors that should be logged but must not block the UI.
  static bool isBenign(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('setstate() called after dispose') ||
        text.contains('setstate() or markneedsbuild() called when widget tree was locked') ||
        text.contains('looking up a deactivated widget') ||
        text.contains('disposed') && text.contains('renderobject') ||
        text.contains('overflowed by') ||
        text.contains('renderflex overflowed') ||
        text.contains('networkimageloadexception') ||
        text.contains('failed to load network image') ||
        text.contains('unable to load asset') ||
        text.contains('image codec') ||
        text.contains('bad state: no element') && text.contains('stream') ||
        text.contains('cancelled') ||
        text.contains('connection closed') ||
        text.contains('connection reset');
  }

  static bool isBenignFlutterDetails(FlutterErrorDetails details) {
    if (details.silent) return true;
    return isBenign(details.exception);
  }

  /// Async / zone errors: log + optional short snackbar (never full-screen).
  static void handleZoneError(Object error, StackTrace stack) {
    AppLogger.logError(error, stack, hint: 'Zone');
    if (kDebugMode || isBenign(error)) return;
    _showTransientNotice(GracefulErrors.userMessage(error));
  }

  /// Framework errors during build/layout: log only at root.
  static void handleFlutterError(FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
    GracefulErrors.record(
      details.exception,
      details.stack,
      hint: 'FlutterError',
    );
  }

  /// Compact placeholder for a failed subtree (release builds).
  static Widget buildBrokenSubtreePlaceholder(FlutterErrorDetails details) {
    final message = isBenignFlutterDetails(details)
        ? null
        : GracefulErrors.userMessage(details.exception);

    if (message == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.lightTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Last-resort navigation when a screen explicitly requests recovery.
  static void recoverToHome() {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    GuardedNavigator.pushNamedAndRemoveUntil(
      nav.context,
      '/main',
      (_) => false,
    );
  }

  static void _showTransientNotice(String message) {
    final now = DateTime.now();
    if (_lastTransientNotice != null &&
        now.difference(_lastTransientNotice!) < const Duration(seconds: 4)) {
      return;
    }
    _lastTransientNotice = now;
    AppToast.showGlobal(message, type: ToastType.warning);
  }
}
