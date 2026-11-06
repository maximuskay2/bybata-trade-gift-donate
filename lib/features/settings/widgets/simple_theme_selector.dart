import 'package:flutter/material.dart';

class SimpleThemeSelector extends StatelessWidget {
  final String currentTheme;
  final ValueChanged<String> onThemeChanged;

  const SimpleThemeSelector({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: currentTheme,
      isExpanded: true,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: 'system', child: Text('System')),
        DropdownMenuItem(value: 'light', child: Text('Light')),
        DropdownMenuItem(value: 'dark', child: Text('Dark')),
      ],
      onChanged: (value) {
        if (value != null) {
          onThemeChanged(value);
        }
      },
    );
  }
}

class SimpleLanguageSelector extends StatelessWidget {
  final String currentLanguage;
  final ValueChanged<String> onLanguageChanged;

  const SimpleLanguageSelector({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: currentLanguage,
      isExpanded: true,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: 'en', child: Text('English')),
        DropdownMenuItem(value: 'es', child: Text('Spanish')),
        DropdownMenuItem(value: 'fr', child: Text('French')),
        DropdownMenuItem(value: 'de', child: Text('German')),
      ],
      onChanged: (value) {
        if (value != null) {
          onLanguageChanged(value);
        }
      },
    );
  }
}