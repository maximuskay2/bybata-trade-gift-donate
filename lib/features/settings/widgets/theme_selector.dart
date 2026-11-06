import 'package:flutter/material.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/haptic_utils.dart';

class ThemeSelector extends StatelessWidget {
  final ThemeProvider themeProvider;

  const ThemeSelector({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose Theme',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...themeProvider.availableThemes.map((themeType) {
            final isSelected = themeProvider.themeModeSetting == themeType;
            return ListTile(
              leading: Icon(_getThemeIcon(themeType)),
              title: Text(_getThemeDisplayName(themeType)),
              trailing: isSelected
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                HapticUtils.selection();
                themeProvider.setThemeMode(themeType);
                Navigator.pop(context);
              },
            );
          }),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Glass Mode'),
            subtitle: const Text('Enable glassmorphism overlay'),
            value: themeProvider.isGlassModeEnabled,
            onChanged: (_) {
              HapticUtils.selection();
              themeProvider.toggleGlassMode();
            },
          ),
        ],
      ),
    );
  }

  IconData _getThemeIcon(AppThemeMode themeType) {
    switch (themeType) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.settings_suggest;
    }
  }

  String _getThemeDisplayName(AppThemeMode themeType) {
    switch (themeType) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }
}