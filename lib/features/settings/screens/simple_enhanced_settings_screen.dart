import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import '../screens/help_support_screen.dart';
import '../../../core/theme/theme_provider.dart';
import 'api_environment_screen.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/widgets/app_toast.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class SimpleEnhancedSettingsScreen extends StatefulWidget {
  const SimpleEnhancedSettingsScreen({super.key});

  @override
  State<SimpleEnhancedSettingsScreen> createState() => _SimpleEnhancedSettingsScreenState();
}

class _SimpleEnhancedSettingsScreenState extends State<SimpleEnhancedSettingsScreen>
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
        _settings = AppSettings();
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

    // Sync theme provider with loaded settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      _syncThemeProviderWithSettings(themeProvider);
    });

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
              leadingIcon: Icons.translate,
              onTap: () => _showLanguageSelector(),
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
          ],
        ),

        const SizedBox(height: 24),

        // Developer / Network Section
        SettingsSection(
          title: 'Developer',
          icon: Icons.developer_mode,
          children: [
            SettingsTile.navigation(
              title: 'API Environment',
              subtitle: 'Select base URL and ping /health',
              leadingIcon: Icons.cloud,
              onTap: () => GuardedNavigator.push(context,
                MaterialPageRoute(
                  builder: (context) => const ApiEnvironmentScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppearanceTab() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Theme Selection Section with Visual Previews
            SettingsSection(
              title: 'Theme Selection',
              icon: Icons.palette,
              children: [
                _buildThemePreviewGrid(themeProvider),
              ],
            ),

            const SizedBox(height: 24),

            // Theme Options Section
            SettingsSection(
              title: 'Theme Options',
              icon: Icons.tune,
              children: [
                SettingsTile.switchTile(
                  title: 'Dynamic Colors',
                  subtitle: 'Use system colors when available',
                  leadingIcon: Icons.color_lens,
                  value: _settings.useDynamicColors,
                  onChanged: (value) => _updateSettings(
                    _settings.copyWith(useDynamicColors: value),
                  ),
                ),
                SettingsTile.navigation(
                  title: 'Current Theme',
                  subtitle: '${themeProvider.themeDisplayName} Theme',
                  leadingIcon: themeProvider.themeIcon,
                  onTap: () => _showAdvancedThemeSelector(themeProvider),
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
              ],
            ),

            const SizedBox(height: 24),

            // Accessibility Section
            SettingsSection(
              title: 'Accessibility',
              icon: Icons.accessibility,
              children: [
                SettingsTile.switchTile(
                  title: 'High Contrast',
                  subtitle: 'Increase text contrast',
                  leadingIcon: Icons.contrast,
                  value: _settings.highContrast,
                  onChanged: (value) => _updateSettings(
                    _settings.copyWith(highContrast: value),
                  ),
                ),
                SettingsTile.switchTile(
                  title: 'Reduce Motion',
                  subtitle: 'Minimize animations and transitions',
                  leadingIcon: Icons.motion_photos_off,
                  value: _settings.reduceMotion,
                  onChanged: (value) => _updateSettings(
                    _settings.copyWith(reduceMotion: value),
                  ),
                ),
              ],
            ),
          ],
        );
      },
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
              subtitle: 'Add an extra layer of security',
              leadingIcon: Icons.security,
              onTap: () => _showPlaceholderDialog('Two-Factor Authentication'),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Developer Options
        SettingsSection(
          title: 'Developer Options',
          icon: Icons.code,
          children: [
            SettingsTile.switchTile(
              title: 'Developer Mode',
              subtitle: 'Enable advanced developer features',
              leadingIcon: Icons.developer_mode,
              value: _settings.developerMode,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(developerMode: value),
              ),
            ),
            SettingsTile.switchTile(
              title: 'Debug Mode',
              subtitle: 'Enable debug logging',
              leadingIcon: Icons.bug_report,
              value: _settings.debugMode,
              onChanged: (value) => _updateSettings(
                _settings.copyWith(debugMode: value),
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

        // Danger Zone Section
        SettingsSection(
          title: 'Danger Zone',
          icon: Icons.warning,
          color: Theme.of(context).colorScheme.error,
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

  String _getLanguageDisplayName(String languageCode) {
    final languages = {
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

  String _getThemeDisplayName(String themeMode) {
    switch (themeMode.toLowerCase()) {
      case 'light':
        return 'Light Theme';
      case 'dark':
        return 'Dark Theme';
      case 'system':
      default:
        return 'System Theme';
    }
  }

  void _showLanguageSelector() {
    final languages = {
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: languages.entries.map((entry) {
              final isSelected = _settings.language == entry.key;
              return ListTile(
                title: Text(entry.value),
                trailing: isSelected
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  _updateSettings(_settings.copyWith(language: entry.key));
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreviewGrid(ThemeProvider themeProvider) {
    final lightScheme = themeProvider.lightTheme.colorScheme;
    final darkScheme = themeProvider.darkTheme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildThemePreviewCard(
              title: 'Light',
              icon: Icons.wb_sunny,
              isSelected: themeProvider.isLightTheme,
              primaryColor: lightScheme.primary,
              backgroundColor: lightScheme.background,
              textColor: lightScheme.onBackground,
              onTap: () async {
                await themeProvider.setLightTheme();
                _updateThemeInSettings('light');
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildThemePreviewCard(
              title: 'Dark',
              icon: Icons.nights_stay,
              isSelected: themeProvider.isDarkTheme,
              primaryColor: darkScheme.primary,
              backgroundColor: darkScheme.background,
              textColor: darkScheme.onBackground,
              onTap: () async {
                await themeProvider.setDarkTheme();
                _updateThemeInSettings('dark');
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildThemePreviewCard(
              title: 'Glass',
              icon: Icons.blur_on,
              isSelected: themeProvider.isGlassTheme,
              primaryColor: darkScheme.primary,
              backgroundColor: darkScheme.background,
              textColor: darkScheme.onBackground,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  darkScheme.primary,
                  darkScheme.secondary,
                ],
              ),
              onTap: () async {
                await themeProvider.setGlassTheme();
                _updateThemeInSettings('glass');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreviewCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color primaryColor,
    required Color backgroundColor,
    required Color textColor,
    Gradient? gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 120,
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? backgroundColor : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? primaryColor.withValues(alpha: 0.2)
                    : textColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? primaryColor : textColor.withValues(alpha: 0.7),
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? primaryColor : textColor.withValues(alpha: 0.8),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 20,
                height: 2,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _updateThemeInSettings(String themeMode) {
    _updateSettings(_settings.copyWith(themeMode: themeMode));
  }

  void _syncThemeProviderWithSettings(ThemeProvider themeProvider) {
    // Sync ThemeProvider state with current settings
    final settingsTheme = _settings.themeMode.toLowerCase();
    if (settingsTheme != themeProvider.currentTheme.toString().split('.').last) {
      switch (settingsTheme) {
        case 'light':
          themeProvider.setLightTheme();
          break;
        case 'dark':
          themeProvider.setDarkTheme();
          break;
        case 'glass':
          themeProvider.setGlassTheme();
          break;
        case 'system':
        default:
          // For system theme, default to light for now
          themeProvider.setLightTheme();
          break;
      }
    }
  }

  void _showAdvancedThemeSelector(ThemeProvider themeProvider) {
    final lightScheme = themeProvider.lightTheme.colorScheme;
    final darkScheme = themeProvider.darkTheme.colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme Selection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: lightScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wb_sunny, color: lightScheme.primary),
              ),
              title: const Text('Light Theme'),
              subtitle: const Text('Clean and bright interface'),
              trailing: themeProvider.isLightTheme 
                  ? Icon(Icons.check_circle, color: lightScheme.primary)
                  : null,
              onTap: () async {
                await themeProvider.setLightTheme();
                _updateThemeInSettings('light');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: darkScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.nights_stay, color: darkScheme.primary),
              ),
              title: const Text('Dark Theme'),
              subtitle: const Text('Easy on the eyes'),
              trailing: themeProvider.isDarkTheme 
                  ? Icon(Icons.check_circle, color: darkScheme.primary)
                  : null,
              onTap: () async {
                await themeProvider.setDarkTheme();
                _updateThemeInSettings('dark');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [darkScheme.primary, darkScheme.secondary],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.blur_on, color: darkScheme.onPrimary),
              ),
              title: const Text('Glass Theme'),
              subtitle: const Text('Modern glassmorphism design'),
              trailing: themeProvider.isGlassTheme 
                  ? Icon(Icons.check_circle, color: darkScheme.primary)
                  : null,
              onTap: () async {
                await themeProvider.setGlassTheme();
                _updateThemeInSettings('glass');
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text('Password change functionality will be implemented soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
            SizedBox(height: 8),
            Text('A platform for community-driven trading and collaboration.'),
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
              await _updateSettings(AppSettings());
              AppToast.show(context, 'Settings reset to default');
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}