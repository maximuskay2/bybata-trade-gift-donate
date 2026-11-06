import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/currency_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../profile/models/user_profile.dart';
import '../services/settings_persistence_service.dart';
import '../widgets/settings_ui.dart';
import '../widgets/timezone_selector.dart';

class SettingsPreferencesScreen extends StatefulWidget {
  final ProfileSettings settings;
  final ValueChanged<ProfileSettings> onSettingsChanged;

  const SettingsPreferencesScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsPreferencesScreen> createState() =>
      _SettingsPreferencesScreenState();
}

class _SettingsPreferencesScreenState extends State<SettingsPreferencesScreen> {
  late ProfileSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  Future<void> _persistLocal() async {
    try {
      await SettingsPersistenceService.instance.saveLocalPreferences(_settings);
      widget.onSettingsChanged(_settings);
      if (mounted) showSettingsSnack(context, 'Preference saved');
    } catch (e) {
      if (mounted) {
        showSettingsSnack(
          context,
          SettingsPersistenceService.instance.messageFromError(e) ??
              'Could not save',
          success: false,
        );
      }
    }
  }

  void _apply(ProfileSettings next) {
    setState(() => _settings = next);
    _persistLocal();
  }

  String _languageName(String code) {
    switch (code) {
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'pt':
        return 'Portuguese';
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final themeSubtitle = themeProvider.isGlassModeEnabled
        ? 'Glass mode'
        : themeProvider.themeModeSetting == AppThemeMode.dark
            ? 'Dark'
            : 'Light';

    return SettingsPageScaffold(
      title: 'App preferences',
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: SettingsUi.screenPadding,
        children: [
          SettingsGroupCard(
            children: [
              SettingsNavTile(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: _languageName(_settings.language),
                onTap: () => _showLanguagePicker(context),
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.payments_rounded,
                title: 'Currency',
                subtitle: CurrencyConstants.labelFor(_settings.currency),
                onTap: () => _showCurrencyPicker(context),
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.schedule_rounded,
                title: 'Timezone',
                subtitle: _settings.timezone,
                onTap: () => _showTimezonePicker(context),
              ),
              const SettingsNavDivider(),
              SettingsNavTile(
                icon: Icons.palette_rounded,
                title: 'Appearance',
                subtitle: themeSubtitle,
                onTap: () => _showThemePicker(context, themeProvider),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PickerSheet(
        title: 'Language',
        children: ['en', 'es', 'fr', 'de', 'pt'].map((code) {
          return ListTile(
            title: Text(_languageName(code)),
            trailing: _settings.language == code
                ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                : null,
            onTap: () {
              _apply(_settings.copyWith(language: code));
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PickerSheet(
        title: 'Currency',
        children: CurrencyConstants.displayCurrencies.map((option) {
          final selected =
              _settings.currency.toUpperCase() == option.code;
          return ListTile(
            leading: Text(
              option.symbol,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(ctx).colorScheme.primary,
              ),
            ),
            title: Text(option.code),
            subtitle: Text(option.name),
            trailing: selected
                ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                : null,
            onTap: () async {
              final next = _settings.copyWith(currency: option.code);
              setState(() => _settings = next);
              Navigator.pop(ctx);
              try {
                await SettingsPersistenceService.instance.saveCurrencyPreference(next);
                widget.onSettingsChanged(next);
                if (mounted) showSettingsSnack(context, 'Currency updated');
              } catch (e) {
                if (mounted) {
                  showSettingsSnack(
                    context,
                    SettingsPersistenceService.instance.messageFromError(e) ??
                        'Could not save currency',
                    success: false,
                  );
                }
              }
            },
          );
        }).toList(),
      ),
    );
  }

  void _showTimezonePicker(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => TimezoneSelector(
        selectedTimezone: _settings.timezone,
        onTimezoneSelected: (tz) {
          _apply(_settings.copyWith(timezone: tz));
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showThemePicker(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PickerSheet(
        title: 'Appearance',
        children: [
          ListTile(
            leading: const Icon(Icons.light_mode_outlined),
            title: const Text('Light'),
            trailing: themeProvider.themeModeSetting == AppThemeMode.light &&
                    !themeProvider.isGlassModeEnabled
                ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                : null,
            onTap: () {
              themeProvider.setThemeMode(AppThemeMode.light);
              Navigator.pop(ctx);
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark'),
            trailing: themeProvider.themeModeSetting == AppThemeMode.dark &&
                    !themeProvider.isGlassModeEnabled
                ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                : null,
            onTap: () {
              themeProvider.setThemeMode(AppThemeMode.dark);
              Navigator.pop(ctx);
              setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.blur_on_rounded),
            title: const Text('Glass'),
            trailing: themeProvider.isGlassModeEnabled
                ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                : null,
            onTap: () {
              themeProvider.toggleGlassMode();
              Navigator.pop(ctx);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _PickerSheet({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            ...children,
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
