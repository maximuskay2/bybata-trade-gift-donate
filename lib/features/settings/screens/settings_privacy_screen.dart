import 'package:flutter/material.dart';

import '../../profile/models/user_profile.dart';
import '../services/settings_persistence_service.dart';
import '../widgets/settings_ui.dart';

class SettingsPrivacyScreen extends StatefulWidget {
  final ProfileSettings settings;
  final ValueChanged<ProfileSettings> onSettingsChanged;

  const SettingsPrivacyScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsPrivacyScreen> createState() => _SettingsPrivacyScreenState();
}

class _SettingsPrivacyScreenState extends State<SettingsPrivacyScreen> {
  late ProfileSettings _settings;
  String? _savingKey;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  Future<void> _update(
    String key,
    ProfileSettings next,
  ) async {
    final previous = _settings;
    setState(() {
      _settings = next;
      _savingKey = key;
    });
    widget.onSettingsChanged(next);
    try {
      await SettingsPersistenceService.instance.savePrivacy(next);
      if (mounted) showSettingsSnack(context, 'Privacy updated');
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
      title: 'Privacy',
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: SettingsUi.screenPadding,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Control what others see on your profile.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ),
          SettingsGroupCard(
            children: [
              SettingsSwitchTile(
                title: 'Public profile',
                subtitle: 'Allow others to find and view your profile',
                value: _settings.isProfilePublic,
                onChanged: _savingKey != null
                    ? null
                    : (v) => _update(
                          'public',
                          _settings.copyWith(isProfilePublic: v),
                        ),
              ),
              const SettingsSwitchDivider(),
              SettingsSwitchTile(
                title: 'Show email',
                subtitle: 'Display your email on your profile',
                value: _settings.showEmail,
                onChanged: _savingKey != null
                    ? null
                    : (v) => _update('email', _settings.copyWith(showEmail: v)),
              ),
              const SettingsSwitchDivider(),
              SettingsSwitchTile(
                title: 'Show phone',
                subtitle: 'Display your phone number on your profile',
                value: _settings.showPhone,
                onChanged: _savingKey != null
                    ? null
                    : (v) => _update('phone', _settings.copyWith(showPhone: v)),
              ),
              const SettingsSwitchDivider(),
              SettingsSwitchTile(
                title: 'Show location',
                subtitle: 'Display your location on your profile',
                value: _settings.showLocation,
                onChanged: _savingKey != null
                    ? null
                    : (v) =>
                        _update('location', _settings.copyWith(showLocation: v)),
              ),
              const SettingsSwitchDivider(),
              SettingsSwitchTile(
                title: 'Allow direct messages',
                subtitle: 'Let other users send you direct messages',
                value: _settings.allowDirectMessages,
                onChanged: _savingKey != null
                    ? null
                    : (v) => _update(
                          'dm',
                          _settings.copyWith(allowDirectMessages: v),
                        ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
