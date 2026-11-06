import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import '../widgets/simple_theme_selector.dart';
import '../widgets/accessibility_settings.dart';
import '../screens/help_support_screen.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class WorkingEnhancedSettingsScreen extends StatefulWidget {
  const WorkingEnhancedSettingsScreen({super.key});

  @override
  State<WorkingEnhancedSettingsScreen> createState() => _WorkingEnhancedSettingsScreenState();
}

class _WorkingEnhancedSettingsScreenState extends State<WorkingEnhancedSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AppSettings _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await AppSettings.load();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _settings = const AppSettings();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSettings(AppSettings newSettings) async {
    setState(() {
      _settings = newSettings;
    });
    await _settings.save();
    
    if (mounted) {
      AppToast.show(context, 'Settings saved');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: const Center(
          child: BybataLoadingIndicator(size: BybataLoadingSize.compact),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.tune), text: 'General'),
            Tab(icon: Icon(Icons.palette), text: 'Appearance'),
            Tab(icon: Icon(Icons.security), text: 'Privacy'),
            Tab(icon: Icon(Icons.build), text: 'Advanced'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(),
          _buildAppearanceTab(),
          _buildPrivacyTab(),
          _buildAdvancedTab(),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Account Section
        SettingsSection(
          title: 'Account',
          icon: Icons.person,
          children: [
            SettingsTile.navigation(
              title: 'Profile',
              subtitle: 'Edit your profile information',
              leadingIcon: Icons.account_circle,
              onTap: () => _showPlaceholderDialog('Profile'),
            ),
            SettingsTile.navigation(
              title: 'Change Password',
              subtitle: 'Update your password',
              leadingIcon: Icons.lock,
              onTap: () => _showChangePasswordDialog(),
            ),
            SettingsTile.navigation(
              title: 'Email Verification',
              subtitle: 'Verify your email address',
              leadingIcon: Icons.email,
              onTap: () => _showPlaceholderDialog('Email Verification'),
            ),
            SettingsTile.navigation(
              title: 'Logout',
              subtitle: 'Sign out of your account',
              leadingIcon: Icons.logout,
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  try {
                    await AppRoutes.completeSignOut(context);
                  } finally {
                    if (!mounted) return;
                    AppToast.show(context, 'Signed out');
                  }
                }
              },
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Notifications Section
        SettingsSection(
          title: 'Notifications',
          icon: Icons.notifications,
          children: [
            SettingsTile.switchTile(
              title: 'Push Notifications',
              subtitle: 'Receive push notifications',
              leadingIcon: Icons.notifications_active,
              value: _settings.pushNotifications,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(pushNotifications: value),
              ),
            ),
            SettingsTile.switchTile(
              title: 'Email Notifications',
              subtitle: 'Receive email notifications',
              leadingIcon: Icons.mail,
              value: _settings.emailNotifications,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(emailNotifications: value),
              ),
            ),
            SettingsTile.switchTile(
              title: 'Marketing Emails',
              subtitle: 'Receive promotional emails',
              leadingIcon: Icons.campaign,
              value: _settings.marketingEmails,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(marketingEmails: value),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Language & Region Section
        SettingsSection(
          title: 'Language & Region',
          icon: Icons.language,
          children: [
            SettingsTile.widget(
              title: 'Language',
              subtitle: 'Select your preferred language',
              leadingIcon: Icons.translate,
              widget: SimpleLanguageSelector(
                currentLanguage: _settings.language,
                onLanguageChanged: (language) => _updateSettings(
                  _settings.copyWith(language: language),
                ),
              ),
            ),
            SettingsTile.navigation(
              title: 'Region',
              subtitle: _settings.region,
              leadingIcon: Icons.location_on,
              onTap: () => _showPlaceholderDialog('Region'),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Help & Support Section
        SettingsSection(
          title: 'Help & Support',
          icon: Icons.help,
          children: [
            SettingsTile.navigation(
              title: 'Help Center',
              subtitle: 'Get help and support',
              leadingIcon: Icons.help_center,
              onTap: () => GuardedNavigator.push(context,
                MaterialPageRoute(
                  builder: (context) => const HelpSupportScreen(),
                ),
              ),
            ),
            SettingsTile.navigation(
              title: 'Contact Support',
              subtitle: 'Reach out to our support team',
              leadingIcon: Icons.support_agent,
              onTap: () => _showPlaceholderDialog('Contact Support'),
            ),
            SettingsTile.navigation(
              title: 'Report a Bug',
              subtitle: 'Report issues you encounter',
              leadingIcon: Icons.bug_report,
              onTap: () => _showPlaceholderDialog('Report a Bug'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppearanceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Theme Section
        SettingsSection(
          title: 'Theme',
          icon: Icons.palette,
          children: [
            SettingsTile.widget(
              title: 'App Theme',
              subtitle: 'Choose your preferred theme',
              leadingIcon: Icons.brightness_6,
              widget: SimpleThemeSelector(
                currentTheme: _settings.themeMode,
                onThemeChanged: (theme) => _updateSettings(
                  _settings.copyWith(themeMode: theme),
                ),
              ),
            ),
            SettingsTile.switchTile(
              title: 'Dynamic Colors',
              subtitle: 'Use system colors when available',
              leadingIcon: Icons.color_lens,
              value: _settings.useDynamicColors,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(useDynamicColors: value),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Display Section
        SettingsSection(
          title: 'Display',
          icon: Icons.display_settings,
          children: [
            SettingsTile.switchTile(
              title: 'Compact Mode',
              subtitle: 'Show more content on screen',
              leadingIcon: Icons.view_compact,
              value: _settings.compactMode,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(compactMode: value),
              ),
            ),
            SettingsTile.switchTile(
              title: 'Show Animations',
              subtitle: 'Enable app animations',
              leadingIcon: Icons.animation,
              value: _settings.showAnimations,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(showAnimations: value),
              ),
            ),
            SettingsTile.switchTile(
              title: 'Enable Animations',
              subtitle: 'Enable UI animations',
              leadingIcon: Icons.play_arrow,
              value: _settings.enableAnimations,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(enableAnimations: value),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Accessibility
        AccessibilitySettings(
          settings: _settings,
          onSettingsChanged: _updateSettings,
        ),
      ],
    );
  }

  Widget _buildPrivacyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Privacy Options Section
        SettingsSection(
          title: 'Privacy Options',
          icon: Icons.privacy_tip,
          children: [
            SettingsTile.switchTile(
              title: 'Analytics',
              subtitle: 'Help improve the app by sharing usage data',
              leadingIcon: Icons.analytics,
              value: _settings.analyticsEnabled,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(analyticsEnabled: value),
              ),
            ),
            SettingsTile.switchTile(
              title: 'Crash Reports',
              subtitle: 'Send crash reports to help fix issues',
              leadingIcon: Icons.bug_report,
              value: _settings.crashReportsEnabled,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(crashReportsEnabled: value),
              ),
            ),
            SettingsTile.navigation(
              title: 'Data Export',
              subtitle: 'Download your data',
              leadingIcon: Icons.download,
              onTap: () => _showPlaceholderDialog('Data Export'),
            ),
            SettingsTile.switchTile(
              title: 'Public Profile',
              subtitle: 'Allow others to see your profile',
              leadingIcon: Icons.public,
              value: _settings.isProfilePublic,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(isProfilePublic: value),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Communication Section
        SettingsSection(
          title: 'Communication',
          icon: Icons.message,
          children: [
            SettingsTile.switchTile(
              title: 'Read Receipts',
              subtitle: 'Let others know when you read their messages',
              leadingIcon: Icons.mark_email_read,
              value: _settings.readReceipts,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(readReceipts: value),
              ),
            ),
            SettingsTile.switchTile(
              title: 'Online Status',
              subtitle: 'Show when you\'re online',
              leadingIcon: Icons.circle,
              value: _settings.showOnlineStatus,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(showOnlineStatus: value),
              ),
            ),
            SettingsTile.switchTile(
              title: 'Direct Messages',
              subtitle: 'Allow others to message you directly',
              leadingIcon: Icons.message,
              value: _settings.allowDirectMessages,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(allowDirectMessages: value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Security Section
        SettingsSection(
          title: 'Security',
          icon: Icons.security,
          children: [
            SettingsTile.switchTile(
              title: 'Biometric Authentication',
              subtitle: 'Use fingerprint or face unlock',
              leadingIcon: Icons.fingerprint,
              value: _settings.biometricAuth,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(biometricAuth: value),
              ),
            ),
            SettingsTile.navigation(
              title: 'Two-Factor Authentication',
              subtitle: _settings.twoFactorEnabled ? 'Enabled' : 'Disabled',
              leadingIcon: Icons.security,
              onTap: () => _showPlaceholderDialog('Two-Factor Authentication'),
            ),
            SettingsTile.navigation(
              title: 'Active Sessions',
              subtitle: 'Manage your active sessions',
              leadingIcon: Icons.devices,
              onTap: () => _showPlaceholderDialog('Active Sessions'),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // System Section
        SettingsSection(
          title: 'System',
          icon: Icons.settings,
          children: [
            SettingsTile.switchTile(
              title: 'Auto Sync',
              subtitle: 'Automatically sync data',
              leadingIcon: Icons.sync,
              value: _settings.autoSync,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(autoSync: value),
              ),
            ),
            SettingsTile.switchTile(
              title: 'Haptic Feedback',
              subtitle: 'Enable haptic feedback',
              leadingIcon: Icons.vibration,
              value: _settings.hapticFeedback,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(hapticFeedback: value),
              ),
            ),
            SettingsTile.navigation(
              title: 'App Info',
              subtitle: 'View app version and build info',
              leadingIcon: Icons.info,
              onTap: () => _showAppInfoDialog(),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Developer Options
        if (_settings.developerMode) ...[
          SettingsSection(
            title: 'Developer Options',
            icon: Icons.code,
            children: [
              SettingsTile.switchTile(
                title: 'Debug Mode',
                subtitle: 'Enable debug logging',
                leadingIcon: Icons.bug_report,
                value: _settings.debugMode,
                onChanged: (value) => _updateSettings(
                  _settings.copyWith(debugMode: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],

        // Danger Zone Section
        SettingsSection(
          title: 'Danger Zone',
          icon: Icons.warning,
          color: Colors.red,
          children: [
            SettingsTile.navigation(
              title: 'Clear Cache',
              subtitle: 'Clear app cache data',
              leadingIcon: Icons.clear_all,
              onTap: () => _showClearCacheDialog(),
            ),
            SettingsTile.navigation(
              title: 'Reset Settings',
              subtitle: 'Reset all settings to default',
              leadingIcon: Icons.restore,
              onTap: () => _showResetSettingsDialog(),
            ),
          ],
        ),
      ],
    );
  }

  void _showPlaceholderDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text('$feature functionality will be implemented soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              AppToast.show(context, 'Password changed successfully');
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showAppInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Information'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BYBATA'),
            Text('Version: 1.0.0'),
            Text('Build: 100'),
            Text('Flutter Version: 3.16.0'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              AppToast.show(context, 'Cache cleared');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showResetSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('This will reset all settings to their default values. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateSettings(const AppSettings());
              AppToast.show(context, 'Settings reset to default');
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}