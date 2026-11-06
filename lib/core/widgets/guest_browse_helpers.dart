import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../navigation/app_routes.dart';
import '../navigation/main_navigation.dart';
import '../providers/auth_provider.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Whether the visitor is signed in.
bool isGuestBrowse(BuildContext context) {
  return !Provider.of<AuthProvider>(context, listen: false).isAuthenticated;
}

/// Gate social / transactional actions on public listing detail screens.
bool requireListingActionSignIn(BuildContext context) {
  return AppRoutes.requireSignIn(context);
}

/// Prompt shown inside hub tabs that require an authenticated user.
class GuestSignInPrompt extends StatelessWidget {
  final String title;
  final String message;

  const GuestSignInPrompt({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurface.withValues(alpha: 0.65),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () =>
                  GuardedNavigator.pushNamed(context, AppConstants.loginRoute),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Returns [child] for authed users, otherwise [GuestSignInPrompt].
class GuestBrowseGate extends StatelessWidget {
  final Widget child;
  final String title;
  final String message;

  const GuestBrowseGate({
    super.key,
    required this.child,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isAuthed = context.watch<AuthProvider>().isAuthenticated;
    if (isAuthed) return child;
    return GuestSignInPrompt(title: title, message: message);
  }
}

/// Hub bottom-nav handler: guests return to browse root; protected tabs ask to sign in.
void handleHubBottomNavTap(BuildContext context, int index) {
  final auth = Provider.of<AuthProvider>(context, listen: false);
  if (!auth.isAuthenticated) {
    if (index == 0) {
      AppRoutes.resetNavigationAfterSignOut();
      return;
    }
    AppRoutes.requireSignIn(context);
    return;
  }
  const routes = ['home', 'chat', 'wallet', 'profile'];
  GuardedNavigator.pushReplacement(context,
    MaterialPageRoute(
      builder: (_) => MainNavigation(initialScreen: routes[index.clamp(0, 3)]),
    ),
  );
}

/// Blocks switching to protected hub tabs while browsing as a guest.
bool guardHubTabForGuest(BuildContext context, int index) {
  if (index == 0) return true;
  return !AppRoutes.requireSignIn(context);
}
