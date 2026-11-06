import 'package:flutter/material.dart';
import 'package:bybata/features/profile/models/user_profile.dart';
import '../screens/enhanced_settings_screen.dart';
import '../screens/help_support_screen.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

UserProfile _demoUserProfileForSettings() {
  final now = DateTime.now();
  return UserProfile(
    id: 'demo-settings',
    firstName: 'Demo',
    lastName: 'User',
    email: 'demo@example.com',
    stats: ProfileStats(),
    trustScore: TrustScore(lastUpdated: now),
    verification: VerificationStatus(),
    settings: ProfileSettings(),
    createdAt: now,
    lastActiveAt: now,
  );
}

class SettingsDemo extends StatelessWidget {
  const SettingsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'BYBATA Settings Integration Demo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Enhanced Settings Screen Demo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.settings,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Enhanced Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Full account settings: profile, privacy, notifications, app preferences, security, and support. Uses a demo profile for this preview.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        GuardedNavigator.push(context,
                          MaterialPageRoute(
                            builder: (context) => EnhancedSettingsScreen(
                              userProfile: _demoUserProfileForSettings(),
                            ),
                          ),
                        );
                      },
                      child: const Text('Open Enhanced Settings'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Help & Support Screen Demo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.help_center,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Help & Support',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Comprehensive help system with FAQs, live chat, contact methods, and support ticket management. Perfect for customer support.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        GuardedNavigator.push(context,
                          MaterialPageRoute(
                            builder: (context) => const HelpSupportScreen(),
                          ),
                        );
                      },
                      child: const Text('Open Help & Support'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Integration Notes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.integration_instructions,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Integration Complete!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '✅ Enhanced Settings Screen integrated into sidebar navigation\n'
                      '✅ Help & Support Screen added to sidebar navigation\n'
                      '✅ All dependencies (url_launcher, shared_preferences) are installed\n'
                      '✅ AppRoutes updated for direct navigation\n'
                      '✅ Settings persist across app restarts\n'
                      '✅ Material 3 design consistency\n'
                      '✅ Accessibility features included',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}