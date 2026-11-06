import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/app_routes.dart';
import '../providers/auth_provider.dart';

/// Wraps a screen that requires authentication.
///
/// If the visitor is not signed in, shows the standard sign-in dialog and
/// pops this route so the screen never mounts protected API calls.
class AuthGate extends StatefulWidget {
  final Widget child;
  final String? title;
  final String? message;
  final String? highlight;

  const AuthGate({
    super.key,
    required this.child,
    this.title,
    this.message,
    this.highlight,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _promptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enforceAuth());
  }

  void _enforceAuth() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) return;

    if (!_promptShown) {
      _promptShown = true;
      AppRoutes.showLoginRequired(
        context,
        title: widget.title,
        message: widget.message,
        highlight: widget.highlight,
      );
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isAuthenticated) {
          return const SizedBox.shrink();
        }
        return widget.child;
      },
    );
  }
}
