import 'package:flutter/material.dart';

import '../../profile/models/user_profile.dart';
import '../../profile/services/profile_cache.dart';
import '../services/settings_persistence_service.dart';
import '../widgets/settings_ui.dart';
import 'settings_account_screen.dart';
import 'settings_notifications_screen.dart';
import 'settings_preferences_screen.dart';
import 'settings_privacy_screen.dart';
import 'settings_security_screen.dart';
import 'settings_support_screen.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Settings hub — profile header, searchable groups, detail screens.
class EnhancedSettingsScreen extends StatefulWidget {
  final UserProfile userProfile;

  const EnhancedSettingsScreen({
    super.key,
    required this.userProfile,
  });

  @override
  State<EnhancedSettingsScreen> createState() => _EnhancedSettingsScreenState();
}

class _HubItem {
  final String section;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> keywords;
  final VoidCallback onTap;

  const _HubItem({
    required this.section,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.keywords,
    required this.onTap,
  });
}

class _EnhancedSettingsScreenState extends State<EnhancedSettingsScreen> {
  late UserProfile _userProfile;
  late ProfileSettings _settings;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _userProfile = widget.userProfile;
    _settings = _userProfile.settings;
    _loadLocalPrefs();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalPrefs() async {
    final merged =
        await SettingsPersistenceService.mergeStoredPrefs(_settings);
    if (mounted) {
      setState(() {
        _settings = merged;
        _userProfile = _userProfile.copyWith(settings: merged);
      });
    }
  }

  void _onSettingsChanged(ProfileSettings next) {
    setState(() {
      _settings = next;
      _userProfile = _userProfile.copyWith(settings: next);
    });
    ProfileCache.saveCurrent(_userProfile);
  }

  String _notificationSummary() {
    final parts = <String>[];
    if (_settings.pushNotifications) parts.add('Push');
    if (_settings.emailNotifications) parts.add('Email');
    if (_settings.marketingEmails) parts.add('Marketing');
    return parts.isEmpty ? 'All off' : parts.join(' · ');
  }

  String _privacySummary() {
    if (!_settings.isProfilePublic) return 'Profile is private';
    final visible = <String>[];
    if (_settings.showEmail) visible.add('email');
    if (_settings.showPhone) visible.add('phone');
    if (_settings.showLocation) visible.add('location');
    if (visible.isEmpty) return 'Public profile';
    return 'Public · shows ${visible.join(', ')}';
  }

  List<_HubItem> _allItems(BuildContext context) {
    return [
      _HubItem(
        section: 'Account',
        title: 'Profile & account',
        subtitle: 'Personal info, verification, password',
        icon: Icons.person_rounded,
        keywords: ['profile', 'password', 'verify', 'email', 'name', 'avatar'],
        onTap: () => GuardedNavigator.push(context,
          MaterialPageRoute(
            builder: (_) => SettingsAccountScreen(
              userProfile: _userProfile,
              onProfileUpdated: (p) {
                setState(() => _userProfile = p);
                ProfileCache.saveCurrent(p);
              },
            ),
          ),
        ),
      ),
      _HubItem(
        section: 'Privacy',
        title: 'Privacy',
        subtitle: _privacySummary(),
        icon: Icons.shield_outlined,
        keywords: ['privacy', 'public', 'email', 'phone', 'location', 'messages'],
        onTap: () async {
          await GuardedNavigator.push(context,
            MaterialPageRoute(
              builder: (_) => SettingsPrivacyScreen(
                settings: _settings,
                onSettingsChanged: _onSettingsChanged,
              ),
            ),
          );
        },
      ),
      _HubItem(
        section: 'Notifications',
        title: 'Notifications',
        subtitle: _notificationSummary(),
        icon: Icons.notifications_outlined,
        keywords: ['push', 'email', 'marketing', 'alerts', 'notify'],
        onTap: () async {
          await GuardedNavigator.push(context,
            MaterialPageRoute(
              builder: (_) => SettingsNotificationsScreen(
                settings: _settings,
                onSettingsChanged: _onSettingsChanged,
              ),
            ),
          );
        },
      ),
      _HubItem(
        section: 'App',
        title: 'App preferences',
        subtitle: '${_settings.language.toUpperCase()} · ${_settings.currency}',
        icon: Icons.tune_rounded,
        keywords: ['language', 'currency', 'timezone', 'theme', 'dark', 'glass'],
        onTap: () async {
          await GuardedNavigator.push(context,
            MaterialPageRoute(
              builder: (_) => SettingsPreferencesScreen(
                settings: _settings,
                onSettingsChanged: _onSettingsChanged,
              ),
            ),
          );
        },
      ),
      _HubItem(
        section: 'Security',
        title: 'Security & data',
        subtitle: 'PIN, sessions, blocked users, export',
        icon: Icons.lock_outline_rounded,
        keywords: ['pin', 'wallet', 'session', 'block', 'download', 'data'],
        onTap: () {
          GuardedNavigator.push(context,
            MaterialPageRoute(
              builder: (_) => const SettingsSecurityScreen(),
            ),
          );
        },
      ),
      _HubItem(
        section: 'Support',
        title: 'Help & legal',
        subtitle: 'FAQ, support, terms, privacy, about',
        icon: Icons.help_outline_rounded,
        keywords: ['help', 'faq', 'support', 'terms', 'privacy', 'about', 'appeal'],
        onTap: () {
          GuardedNavigator.push(context,
            MaterialPageRoute(
              builder: (_) => const SettingsSupportScreen(),
            ),
          );
        },
      ),
    ];
  }

  List<_HubItem> _filteredItems(BuildContext context) {
    final items = _allItems(context);
    if (_query.isEmpty) return items;
    return items.where((item) {
      final haystack = [
        item.section,
        item.title,
        item.subtitle,
        ...item.keywords,
      ].join(' ').toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems(context);
    final grouped = <String, List<_HubItem>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item.section, () => []).add(item);
    }

    return SettingsPageScaffold(
        title: 'Settings',
        showSearch: true,
        searchController: _searchController,
        onSearchChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        onBack: () => Navigator.pop(context, _userProfile),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: SettingsUi.screenPadding,
          children: [
            SettingsProfileHeader(profile: _userProfile),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'No settings match "$_query"',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              )
            else
              ...grouped.entries.expand((entry) {
                return [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                  SettingsGroupCard(
                    children: [
                      for (var i = 0; i < entry.value.length; i++) ...[
                        if (i > 0) const SettingsNavDivider(),
                        SettingsHubTile(
                          icon: entry.value[i].icon,
                          title: entry.value[i].title,
                          subtitle: entry.value[i].subtitle,
                          onTap: entry.value[i].onTap,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                ];
              }),
            const SizedBox(height: 8),
            SettingsDangerCard(
              buttonLabel: 'Delete account',
              onPressed: () =>
                  SettingsDeleteAccountHandler.showDeleteDialog(context),
            ),
            const SizedBox(height: 24),
          ],
        ),
    );
  }
}
