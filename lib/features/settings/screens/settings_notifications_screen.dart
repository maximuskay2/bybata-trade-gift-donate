import 'package:flutter/material.dart';

import '../../profile/models/user_profile.dart';
import '../services/settings_persistence_service.dart';
import '../widgets/settings_ui.dart';
import 'notification_preferences_screen.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

class SettingsNotificationsScreen extends StatefulWidget {
  final ProfileSettings settings;
  final ValueChanged<ProfileSettings> onSettingsChanged;

  const SettingsNotificationsScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsNotificationsScreen> createState() =>
      _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState
    extends State<SettingsNotificationsScreen> {
  late ProfileSettings _settings;
  String? _savingKey;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  Future<void> _update(String key, ProfileSettings next) async {
    final previous = _settings;
    setState(() {
      _settings = next;
      _savingKey = key;
    });
    widget.onSettingsChanged(next);
    try {
      await SettingsPersistenceService.instance.saveNotifications(next);
      if (mounted) showSettingsSnack(context, 'Notification settings updated');
    } catch (e) {
      if (mounted) {
        setState(() => _settings = previous);
        widget.onSettingsChanged(previous);
        showSettingsSnack(
          context,
          SettingsPersistenceService.instance.messageFromError(e) ??
              'Could not save',
          success: false,
        );
      }
    } finally {
      if (mounted) setState(() => _savingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Notifications',
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: SettingsUi.screenPadding,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Choose how Bybata reaches you on this device and by email.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ),
          SettingsGroupCard(
            children: [
              SettingsSwitchTile(
                title: 'Push notifications',
                subtitle: 'Alerts on this device',
                value: _settings.pushNotifications,
                onChanged: _savingKey != null
                    ? null
                    : (v) => _update(
                          'push',
                          _settings.copyWith(pushNotifications: v),
                        ),
              ),
              const SettingsSwitchDivider(),
              SettingsSwitchTile(
                title: 'Email notifications',
                subtitle: 'Important updates in your inbox',
                value: _settings.emailNotifications,
                onChanged: _savingKey != null
                    ? null
                    : (v) => _update(
                          'email',
                          _settings.copyWith(emailNotifications: v),
                        ),
              ),
              const SettingsSwitchDivider(),
              SettingsSwitchTile(
                title: 'Marketing emails',
                subtitle: 'Promotions and newsletters',
                value: _settings.marketingEmails,
                onChanged: _savingKey != null
                    ? null
                    : (v) => _update(
                          'marketing',
                          _settings.copyWith(marketingEmails: v),
                        ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsGroupCard(
            children: [
              SettingsNavTile(
                icon: Icons.tune_rounded,
                title: 'Notification preferences',
                subtitle: 'Trades, gifts, campaigns, weekly reports',
                onTap: () {
                  GuardedNavigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationPreferencesScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
