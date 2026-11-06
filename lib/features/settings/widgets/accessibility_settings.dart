import 'package:flutter/material.dart';
import '../models/app_settings.dart';

class AccessibilitySettings extends StatelessWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  const AccessibilitySettings({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.accessibility,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Accessibility',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('High Contrast'),
              subtitle: const Text('Increase color contrast for better visibility'),
              value: settings.highContrast,
              onChanged: (value) {
                onSettingsChanged(settings.copyWith(highContrast: value));
              },
            ),
            SwitchListTile(
              title: const Text('Reduce Motion'),
              subtitle: const Text('Minimize animations and transitions'),
              value: settings.reduceMotion,
              onChanged: (value) {
                onSettingsChanged(settings.copyWith(reduceMotion: value));
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('Text Size'),
              subtitle: Text('Current: ${(settings.textScale * 100).round()}%'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: settings.textScale > 0.8
                        ? () {
                            final newScale = (settings.textScale - 0.1).clamp(0.8, 2.0);
                            onSettingsChanged(settings.copyWith(textScale: newScale));
                          }
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    onPressed: settings.textScale < 2.0
                        ? () {
                            final newScale = (settings.textScale + 0.1).clamp(0.8, 2.0);
                            onSettingsChanged(settings.copyWith(textScale: newScale));
                          }
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}