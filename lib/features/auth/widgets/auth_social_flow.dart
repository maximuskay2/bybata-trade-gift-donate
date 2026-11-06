import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/auth_provider.dart';
import '../utils/auth_errors.dart';
import '../../karma/providers/karma_provider.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Shared navigation + side effects after Google / Apple auth.
class AuthSocialFlow {
  AuthSocialFlow._();

  static Future<bool> signInWithGoogle(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (!success || !context.mounted) return false;
    await _afterSocialAuth(context, isNewSignup: false);
    return true;
  }

  static Future<bool> signInWithApple(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithApple();
    if (!success || !context.mounted) return false;
    await _afterSocialAuth(context, isNewSignup: false);
    return true;
  }

  static Future<void> _afterSocialAuth(
    BuildContext context, {
    required bool isNewSignup,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_invite_code');
    } catch (_) {}

    if (context.mounted) {
      try {
        final karma = context.read<KarmaProvider>();
        await karma.addTransaction(100, 'welcome_bonus', 'Welcome bonus');
      } catch (_) {}
    }

    if (context.mounted) {
      GuardedNavigator.pushReplacementNamed(context, '/main');
    }
  }

  static String errorMessage(
    BuildContext context, {
    AuthFlow flow = AuthFlow.googleSignIn,
  }) {
    return AuthErrors.sanitizeProviderMessage(
      context.read<AuthProvider>().errorMessage,
      flow: flow,
    );
  }
}
