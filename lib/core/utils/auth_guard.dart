import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../navigation/app_routes.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Utility class for handling authentication-required actions across the app
class AuthGuard {
  // Private constructor to prevent instantiation
  AuthGuard._();

  /// Check if user is authenticated, show login dialog if not
  /// Returns true if authenticated, false if not
  static bool requireAuth(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      AppRoutes.showLoginRequired(context);
      return false;
    }
    return true;
  }

  /// Execute an action that requires authentication
  /// If not authenticated, shows login dialog. Otherwise executes the action.
  static void executeIfAuthenticated(
    BuildContext context, {
    required VoidCallback onAuthenticated,
    VoidCallback? onNotAuthenticated,
  }) {
    if (requireAuth(context)) {
      onAuthenticated();
    } else {
      onNotAuthenticated?.call();
    }
  }

  /// Navigate to a route that requires authentication
  /// If not authenticated, shows login dialog instead
  static void navigateIfAuthenticated(
    BuildContext context, {
    required String routeName,
    Object? arguments,
  }) {
    executeIfAuthenticated(
      context,
      onAuthenticated: () {
        GuardedNavigator.pushNamed(context,
          routeName,
          arguments: arguments,
        );
      },
    );
  }
}
