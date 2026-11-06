import 'package:flutter/material.dart';

import '../errors/graceful_errors.dart';

/// Wraps a screen subtree. Framework errors are handled globally (log + compact
/// placeholder); async failures should use [GracefulErrors.guard] or
/// [GracefulErrors.screen] inside the screen's own state.
class SafeScreen extends StatelessWidget {
  const SafeScreen({
    super.key,
    required this.child,
    this.onError,
    this.errorMessage,
    this.allowRetry = true,
  });

  final Widget child;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final String? errorMessage;
  final bool allowRetry;

  @override
  Widget build(BuildContext context) => child;
}
