import 'package:flutter/material.dart';
import '../../../core/utils/haptic_utils.dart';

class LanguageSelector extends StatelessWidget {
  final String currentLanguage;
  final ValueChanged<String> onLanguageChanged;

  const LanguageSelector({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
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

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose Language',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...languages.entries.map((entry) {
            final isSelected = currentLanguage == entry.key;
            return ListTile(
              title: Text(entry.value),
              trailing: isSelected
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                HapticUtils.selection();
                onLanguageChanged(entry.key);
              },
            );
          }),
        ],
      ),
    );
  }
}