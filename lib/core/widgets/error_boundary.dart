import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../errors/global_error_handler.dart';
import '../errors/graceful_errors.dart';
import '../theme/app_theme.dart';

/// Lightweight wrapper — does **not** replace the whole app on framework errors.
///
/// Previously this widget hooked [FlutterError.onError] and unmounted the
/// entire tree (showing "Oops! Something went wrong"). That is disabled for
/// production; use [GracefulErrors] on individual screens instead.
class AppErrorBoundary extends StatelessWidget {
  final Widget child;
  final Widget? errorWidget;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final String? errorMessage;
  final bool showStackTrace;
  final bool allowRetry;

  const AppErrorBoundary({
    super.key,
    required this.child,
    this.errorWidget,
    this.onError,
    this.errorMessage,
    this.showStackTrace = false,
    this.allowRetry = true,
  });

  @override
  Widget build(BuildContext context) => child;
}

/// Optional full-screen error UI for screens that set error state explicitly.
class DefaultErrorWidget extends StatelessWidget {
  final Object? error;
  final StackTrace? stackTrace;
  final String? errorMessage;
  final bool showStackTrace;
  final VoidCallback? onRetry;

  const DefaultErrorWidget({
    super.key,
    this.error,
    this.stackTrace,
    this.errorMessage,
    this.showStackTrace = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = errorMessage ??
        (error != null
            ? GracefulErrors.userMessage(error!)
            : GracefulErrors.defaultMessage);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: AppColors.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 20),
              Text(
                "Couldn't load this",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 28),
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: GlobalErrorHandler.recoverToHome,
                child: const Text('Go to home'),
              ),
              if (kDebugMode && showStackTrace && stackTrace != null) ...[
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      '$error\n\n$stackTrace',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NetworkErrorBoundary extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRetry;
  final String? errorMessage;

  const NetworkErrorBoundary({
    super.key,
    required this.child,
    this.onRetry,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return AppErrorBoundary(
      errorMessage: errorMessage,
      child: child,
    );
  }
}

class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorWidget({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return DefaultErrorWidget(
      errorMessage: 'Check your connection and try again.',
      onRetry: onRetry,
    );
  }
}
