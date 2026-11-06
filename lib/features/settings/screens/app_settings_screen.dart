import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/loading_states.dart';
import '../../../core/widgets/error_boundary.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../features/common/widgets/interaction_components.dart';
import '../models/app_settings.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import '../widgets/theme_selector.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/navigation/app_routes.dart';
import '../widgets/language_selector.dart';
import '../widgets/accessibility_settings.dart';
import 'help_support_screen.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AppSettings _settings = AppSettings();
  bool _isLoading = false;
  bool _hasChanges = false;

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
    setState(() => _isLoading = true);
    try {
      // Simulate loading settings from storage
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _settings = AppSettings.loadFromStorage());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_hasChanges) return;
    
    HapticUtils.light();
    setState(() => _isLoading = true);
    
    try {
      await _settings.save();
      setState(() => _hasChanges = false);
      
      if (mounted) {
        AppToast.show(context, 'Settings saved successfully!');
      }
      HapticUtils.success();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to save settings: $e');
      }
      HapticUtils.error();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateSetting<T>(T newValue, T Function() getter, Function(T) setter) {
    if (getter() != newValue) {
      setState(() {
        setter(newValue);
        _hasChanges = true;
      });
      HapticUtils.light();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppErrorBoundary(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              title: const Text(
                'Settings',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              centerTitle: false,
              floating: true,
              snap: true,
              actions: [
                if (_hasChanges) ...[
                  TextButton.icon(
                    onPressed: _isLoading ? null : _saveSettings,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Save'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                IconButton(
                  onPressed: () => _showSearchSettings(),
                  icon: const Icon(Icons.search),
                  tooltip: 'Search Settings',
                ),
                const SizedBox(width: 8),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'General', icon: Icon(Icons.settings, size: 20)),
                  Tab(text: 'Appearance', icon: Icon(Icons.palette, size: 20)),
                  Tab(text: 'Privacy', icon: Icon(Icons.security, size: 20)),
                  Tab(text: 'Advanced', icon: Icon(Icons.tune, size: 20)),
                ],
              ),
            ),
          ],
          body: _isLoading
              ? const Center(
                  child: SmartLoadingIndicator(
                    message: 'Loading settings...',
                    type: LoadingType.circular,
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGeneralTab(),
                    _buildAppearanceTab(),
                    _buildPrivacyTab(),
                    _buildAdvancedTab(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Account Section
          SettingsSection(
            title: 'Account',
            icon: Icons.person,
            children: [
              SettingsTile.navigation(
                title: 'Profile Information',
                subtitle: 'Update your personal details',
                leading: const Icon(Icons.account_circle),
                onTap: () => _navigateToProfile(),
              ),
              SettingsTile.navigation(
                title: 'Verification Status',
                subtitle: _settings.isVerified ? 'Verified account' : 'Verify your account',
                leading: Icon(
                  _settings.isVerified ? Icons.verified : Icons.verified_user_outlined,
                  color: _settings.isVerified ? Theme.of(context).colorScheme.primary : null,
                ),
                trailing: _settings.isVerified
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
                onTap: () => _navigateToVerification(),
              ),
              SettingsTile.navigation(
                title: 'Change Password',
                subtitle: 'Update your account password',
                leading: const Icon(Icons.lock_outline),
                onTap: () => _showChangePasswordDialog(),
              ),
              SettingsTile.navigation(
                title: 'Logout',
                subtitle: 'Sign out of your account',
                leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
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
                subtitle: 'Receive notifications on your device',
                leading: const Icon(Icons.notifications_outlined),
                value: _settings.pushNotifications,
                onChanged: (value) => _updateSetting(
                  value,
                  () => _settings.pushNotifications,
                  (val) => _settings = _settings.copyWith(pushNotifications: val),
                ),
              ),
              SettingsTile.switchTile(
                title: 'Email Notifications',
                subtitle: 'Receive important updates via email',
                leading: const Icon(Icons.email_outlined),
                value: _settings.emailNotifications,
                onChanged: (value) => _updateSetting(
                  value,
                  () => _settings.emailNotifications,
                  (val) => _settings = _settings.copyWith(emailNotifications: val),
                ),
              ),
              SettingsTile.navigation(
                title: 'Notification Preferences',
                subtitle: 'Customize what notifications you receive',
                leading: const Icon(Icons.tune),
                onTap: () => _showNotificationPreferences(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Language & Region Section
          SettingsSection(
            title: 'Language & Region',
            icon: Icons.language,
            children: [
              SettingsTile.navigation(
                title: 'Language',
                subtitle: _getLanguageDisplayName(_settings.language),
                leading: const Icon(Icons.translate),
                onTap: () => _showLanguageSelector(),
              ),
              SettingsTile.navigation(
                title: 'Currency',
                subtitle: _settings.currency,
                leading: const Icon(Icons.attach_money),
                onTap: () => _showCurrencySelector(),
              ),
              SettingsTile.navigation(
                title: 'Date & Time Format',
                subtitle: _settings.timeFormat24h ? '24-hour format' : '12-hour format',
                leading: const Icon(Icons.schedule),
                onTap: () => _showTimeFormatSelector(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Support Section
          SettingsSection(
            title: 'Help & Support',
            icon: Icons.help,
            children: [
              SettingsTile.navigation(
                title: 'Help Center',
                subtitle: 'Get help and find answers',
                leading: const Icon(Icons.help_center),
                onTap: () => GuardedNavigator.push(context,
                  MaterialPageRoute(
                    builder: (context) => const HelpSupportScreen(),
                  ),
                ),
              ),
              SettingsTile.navigation(
                title: 'Contact Support',
                subtitle: 'Get in touch with our team',
                leading: const Icon(Icons.contact_support),
                onTap: () => GuardedNavigator.push(context,
                  MaterialPageRoute(
                    builder: (context) => const HelpSupportScreen(initialTab: 1),
                  ),
                ),
              ),
              SettingsTile.navigation(
                title: 'Send Feedback',
                subtitle: 'Help us improve the app',
                leading: const Icon(Icons.feedback),
                onTap: () => _showFeedbackDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Theme Section
          SettingsSection(
            title: 'Theme',
            icon: Icons.palette,
            children: [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return Column(
                    children: [
                      SettingsTile.navigation(
                        title: 'App Theme',
                        subtitle: themeProvider.themeDisplayName,
                        leading: Icon(themeProvider.themeIcon),
                        onTap: () => _showThemeSelector(themeProvider),
                      ),
                      SettingsTile.switchTile(
                        title: 'Dark Mode',
                        subtitle: 'Override system appearance',
                        leading: const Icon(Icons.dark_mode),
                        value: themeProvider.themeModeSetting == AppThemeMode.dark,
                        onChanged: (value) => themeProvider.setThemeMode(
                          value ? AppThemeMode.dark : AppThemeMode.light,
                        ),
                      ),
                      SettingsTile.switchTile(
                        title: 'Glass Mode',
                        subtitle: 'Enable glassmorphism overlay',
                        leading: const Icon(Icons.blur_on),
                        value: themeProvider.isGlassModeEnabled,
                        onChanged: (_) => themeProvider.toggleGlassMode(),
                      ),
                    ],
                  );
                },
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
                title: 'Show Animations',
                subtitle: 'Enable smooth transitions and animations',
                leading: const Icon(Icons.animation),
                value: _settings.enableAnimations,
                onChanged: (value) => _updateSetting(
                  value,
                  () => _settings.enableAnimations,
                  (val) => _settings = _settings.copyWith(enableAnimations: val),
                ),
              ),
              SettingsTile.switchTile(
                title: 'Haptic Feedback',
                subtitle: 'Feel vibrations when interacting with the app',
                leading: const Icon(Icons.vibration),
                value: _settings.hapticFeedback,
                onChanged: (value) => _updateSetting(
                  value,
                  () => _settings.hapticFeedback,
                  (val) => _settings = _settings.copyWith(hapticFeedback: val),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Accessibility Section
          AccessibilitySettings(
            settings: _settings,
            onSettingsChanged: (newSettings) {
              setState(() {
                _settings = newSettings;
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Privacy Section
          SettingsSection(
            title: 'Profile Privacy',
            icon: Icons.privacy_tip,
            children: [
              SettingsTile.switchTile(
                title: 'Public Profile',
                subtitle: 'Allow others to find and view your profile',
                leading: const Icon(Icons.public),
                value: _settings.isProfilePublic,
                onChanged: (value) => _updateSetting(
                  value,
                  () => _settings.isProfilePublic,
                  (val) => _settings = _settings.copyWith(isProfilePublic: val),
                ),
              ),
              SettingsTile.switchTile(
                title: 'Show Email',
                subtitle: 'Display your email on your profile',
                leading: const Icon(Icons.email),
                value: _settings.showEmail,
                onChanged: (value) => _updateSetting(
                  value,
                  () => _settings.showEmail,
                  (val) => _settings = _settings.copyWith(showEmail: val),
                ),
              ),
              SettingsTile.switchTile(
                title: 'Show Phone',
                subtitle: 'Display your phone number on your profile',
                leading: const Icon(Icons.phone),
                value: _settings.showPhone,
                onChanged: (value) => _updateSetting(
                  value,
                  () => _settings.showPhone,
                  (val) => _settings = _settings.copyWith(showPhone: val),
                ),
              ),
              SettingsTile.switchTile(
                title: 'Show Location',
                subtitle: 'Display your location on your profile',
                leading: const Icon(Icons.location_on),
                value: _settings.showLocation,
                onChanged: (value) => _updateSetting(
                  value,
                  () => _settings.showLocation,
                  (val) => _settings = _settings.copyWith(showLocation: val),
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
                title: 'Allow Direct Messages',
                subtitle: 'Let other users send you direct messages',
                leading: const Icon(Icons.message),
                value: _settings.allowDirectMessages,
                onChanged: (value) => _updateSetting(
                  value,
                  () => _settings.allowDirectMessages,
                  (val) => _settings = _settings.copyWith(allowDirectMessages: val),
                ),
              ),
              SettingsTile.switchTile(
                title: 'Show Online Status',
                subtitle: 'Let others see when you\'re online',
                leading: Icon(Icons.circle, color: Theme.of(context).colorScheme.primary),
                value: _settings.showOnlineStatus,
                onChanged: (value) => _updateSetting(
                  value,
                  () => _settings.showOnlineStatus,
                  (val) => _settings = _settings.copyWith(showOnlineStatus: val),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Security Section
          SettingsSection(
            title: 'Security',
            icon: Icons.security,
            children: [
              SettingsTile.navigation(
                title: 'Two-Factor Authentication',
                subtitle: _settings.twoFactorEnabled ? 'Enabled' : 'Disabled',
                leading: const Icon(Icons.security),
                trailing: _settings.twoFactorEnabled
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => _showTwoFactorSettings(),
              ),
              SettingsTile.navigation(
                title: 'Active Sessions',
                subtitle: 'Manage your logged in devices',
                leading: const Icon(Icons.devices),
                onTap: () => _showActiveSessions(),
              ),
              SettingsTile.navigation(
                title: 'Blocked Users',
                subtitle: 'Manage blocked users list',
                leading: const Icon(Icons.block),
                onTap: () => _showBlockedUsers(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Data & Storage Section
          SettingsSection(
            title: 'Data & Storage',
            icon: Icons.storage,
            children: [
              SettingsTile.navigation(
                title: 'Download My Data',
                subtitle: 'Request a copy of your data',
                leading: const Icon(Icons.download),
                onTap: () => _requestDataDownload(),
              ),
              SettingsTile.navigation(
                title: 'Clear Cache',
                subtitle: 'Free up storage space',
                leading: const Icon(Icons.cleaning_services),
                onTap: () => _clearCache(),
              ),
              SettingsTile.switchTile(
                title: 'Auto-sync',
                subtitle: 'Automatically sync data in background',
                leading: const Icon(Icons.sync),
                value: _settings.autoSync,
                onChanged: (value) => _updateSetting(
                  value,
                  () => _settings.autoSync,
                  (val) => _settings = _settings.copyWith(autoSync: val),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Developer Section
          SettingsSection(
            title: 'Developer Options',
            icon: Icons.code,
            children: [
              SettingsTile.switchTile(
                title: 'Debug Mode',
                subtitle: 'Show additional debug information',
                leading: const Icon(Icons.bug_report),
                value: _settings.debugMode,
                onChanged: (value) => _updateSetting(
                  value,
                  () => _settings.debugMode,
                  (val) => _settings = _settings.copyWith(debugMode: val),
                ),
              ),
              SettingsTile.navigation(
                title: 'App Logs',
                subtitle: 'View application logs',
                leading: const Icon(Icons.list_alt),
                onTap: () => _showAppLogs(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Legal Section
          SettingsSection(
            title: 'Legal',
            icon: Icons.gavel,
            children: [
              SettingsTile.navigation(
                title: 'Terms of Service',
                subtitle: 'Read our terms and conditions',
                leading: const Icon(Icons.description),
                onTap: () => _showTermsOfService(),
              ),
              SettingsTile.navigation(
                title: 'Privacy Policy',
                subtitle: 'Learn how we protect your privacy',
                leading: const Icon(Icons.privacy_tip),
                onTap: () => _showPrivacyPolicy(),
              ),
              SettingsTile.navigation(
                title: 'About',
                subtitle: 'App version and information',
                leading: const Icon(Icons.info),
                onTap: () => _showAbout(),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Danger Zone
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Theme.of(context).colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Danger Zone',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteAccountDialog(),
                    icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                    label: Text(
                      'Delete Account',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).colorScheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Helper methods
  String _getLanguageDisplayName(String languageCode) {
    const languages = {
      'en': 'English',
      'es': 'Español',
      'fr': 'Français',
      'de': 'Deutsch',
      'pt': 'Português',
      'it': 'Italiano',
      'ja': '日本語',
      'ko': '한국어',
      'zh': '中文',
      'ar': 'العربية',
    };
    return languages[languageCode] ?? 'English';
  }

  // Navigation methods
  void _navigateToProfile() {
    // Navigate to profile edit screen
    AppToast.show(context, 'Navigate to Profile Edit');
  }

  void _navigateToVerification() {
    // Navigate to verification screen
    AppToast.show(context, 'Navigate to Verification');
  }

  // Dialog methods
  void _showSearchSettings() {
    showSearch(
      context: context,
      delegate: SettingsSearchDelegate(),
    );
  }

  void _showChangePasswordDialog() {
    // Implementation for change password
    AppToast.show(context, 'Change password dialog');
  }

  void _showNotificationPreferences() {
    // Implementation for notification preferences
    AppToast.show(context, 'Notification preferences dialog');
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => LanguageSelector(
        currentLanguage: _settings.language,
        onLanguageChanged: (language) {
          _updateSetting(
            language,
            () => _settings.language,
            (val) => _settings = _settings.copyWith(language: val),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCurrencySelector() {
    // Implementation for currency selector
    AppToast.show(context, 'Currency selector dialog');
  }

  void _showTimeFormatSelector() {
    // Implementation for time format selector
    AppToast.show(context, 'Time format selector dialog');
  }

  void _showThemeSelector(ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ThemeSelector(themeProvider: themeProvider),
    );
  }

  void _showFeedbackDialog() {
    // Implementation for feedback dialog
    AppToast.show(context, 'Feedback dialog');
  }

  void _showTwoFactorSettings() {
    // Implementation for 2FA settings
    AppToast.show(context, 'Two-factor authentication settings');
  }

  void _showActiveSessions() {
    // Implementation for active sessions
    AppToast.show(context, 'Active sessions management');
  }

  void _showBlockedUsers() {
    // Implementation for blocked users
    AppToast.show(context, 'Blocked users management');
  }

  void _requestDataDownload() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Your Data'),
        content: const Text(
          'We will prepare your data and send a download link to your email address. This may take up to 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ActionButton(
            text: 'Request',
            onPressed: () {
              Navigator.pop(context);
              AppToast.show(context, 'Data download request submitted!');
            },
          ),
        ],
      ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data and free up storage space.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ActionButton(
            text: 'Clear',
            onPressed: () async {
              Navigator.pop(context);
              // Simulate clearing cache
              await Future.delayed(const Duration(seconds: 1));
              if (mounted) {
                AppToast.show(context, 'Cache cleared successfully!');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAppLogs() {
    // Implementation for app logs viewer
    AppToast.show(context, 'App logs viewer');
  }

  void _showTermsOfService() {
    // Implementation for terms of service
    AppToast.show(context, 'Terms of service viewer');
  }

  void _showPrivacyPolicy() {
    // Implementation for privacy policy
    AppToast.show(context, 'Privacy policy viewer');
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'BYBATA',
      applicationVersion: '1.0.0+1',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Icon(
          Icons.swap_horiz,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 32,
        ),
      ),
      children: const [
        Text(
          'A community-driven platform for trading, gifting, and helping others without traditional money.',
        ),
        SizedBox(height: 16),
        Text('Made with ❤️ for the community'),
      ],
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
            SizedBox(width: 8),
            Text('Delete Account'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ActionButton(
            text: 'Delete',
            style: ActionButtonStyle.danger,
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteAccount();
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    // Implementation for account deletion confirmation
    AppToast.show(context, 'Account deletion is not yet implemented');
  }
}

// Settings search delegate
class SettingsSearchDelegate extends SearchDelegate<String> {
  final List<String> _settings = [
    'Theme',
    'Language',
    'Notifications',
    'Privacy',
    'Security',
    'Account',
    'Dark Mode',
    'Haptic Feedback',
    'Two-Factor Authentication',
    'Blocked Users',
    'Download Data',
    'Delete Account',
  ];

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, ''),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = _settings
        .where((setting) => setting.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final setting = results[index];
        return ListTile(
          title: Text(setting),
          onTap: () {
            close(context, setting);
          },
        );
      },
    );
  }
}