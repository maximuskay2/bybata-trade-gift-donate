import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/navigation/main_navigation.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Placeholder screen for features that are not yet available.
/// Shows "Coming Soon" with a "Go Back Home" button.
class ComingSoonScreen extends StatelessWidget {
  final String? title;

  const ComingSoonScreen({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.construction_rounded,
                size: 80,
                color: AppTheme.communityColor.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 24),
              Text(
                title ?? 'Coming Soon',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We\'re working hard to bring this feature to you. Stay tuned!',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    GuardedNavigator.pushAndRemoveUntil(context, 
                      MaterialPageRoute(
                        builder: (_) => const MainNavigation(initialScreen: 'home'),
                      ),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Go Back Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
