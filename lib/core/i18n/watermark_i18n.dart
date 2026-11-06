import 'dart:convert';
import 'package:flutter/services.dart';

/// Manages watermark-specific translations
/// Supports multiple languages with fallback to English
class WatermarkI18n {
  static final WatermarkI18n _instance = WatermarkI18n._internal();
  
  late Map<String, Map<String, String>> _translations;
  String _currentLanguage = 'en';
  bool _isInitialized = false;

  WatermarkI18n._internal();

  factory WatermarkI18n() {
    return _instance;
  }

  /// Initialize translations from JSON file
  Future<void> initialize({String? language}) async {
    if (_isInitialized) return;

    try {
      final jsonString =
          await rootBundle.loadString('lib/l10n/watermark_strings.json');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      _translations = {};
      jsonData.forEach((lang, strings) {
        _translations[lang] = Map<String, String>.from(
          (strings as Map<String, dynamic>)['watermark'] as Map<String, dynamic>,
        );
      });

      if (language != null && _translations.containsKey(language)) {
        _currentLanguage = language;
      }

      _isInitialized = true;
    } catch (e) {
      // Silently fail, use hardcoded defaults
      _loadDefaults();
      _isInitialized = true;
    }
  }

  /// Set the current language
  void setLanguage(String languageCode) {
    if (_translations.containsKey(languageCode)) {
      _currentLanguage = languageCode;
    } else {
      _currentLanguage = 'en'; // Fallback to English
    }
  }

  /// Get translated string by key
  String get(String key) {
    final lang = _translations[_currentLanguage] ?? _translations['en'];
    return lang?[key] ?? _getDefault(key) ?? key;
  }

  /// Get translated string with fallback language
  String getWithFallback(String key, {String fallbackLang = 'en'}) {
    final lang = _translations[_currentLanguage];
    if (lang != null && lang.containsKey(key)) {
      return lang[key]!;
    }

    final fallback = _translations[fallbackLang];
    if (fallback != null && fallback.containsKey(key)) {
      return fallback[key]!;
    }

    return _getDefault(key) ?? key;
  }

  /// Load hardcoded default values (fallback if JSON fails to load)
  void _loadDefaults() {
    _translations = {
      'en': {
        'settings_title': 'Watermark Settings',
        'settings_description': 'Protect your uploads with watermarks',
        'enable_label': 'Watermarks Enabled',
        'disable_label': 'Watermarks Disabled',
        'opacity_label': 'Watermark Opacity',
        'invisible': 'Invisible',
        'maximum': 'Maximum',
        'opacity_visible': 'Visible',
        'preview_text_visible': 'Your username will be fully visible on all your uploads',
        'preview_text_semi': 'Your username will be semi-transparent on all your uploads',
        'preview_text_invisible': 'Your username will be invisible on all your uploads',
        'disabled_warning':
            'Watermarks are disabled. Your uploads will not have any watermark protection.',
        'fallback_handle': '@bybata',
      },
    };
  }

  /// Get default English value
  String? _getDefault(String key) {
    return _translations['en']?[key];
  }

  /// Get all available languages
  List<String> get availableLanguages =>
      _translations.keys.toList()..sort();

  /// Get current language
  String get currentLanguage => _currentLanguage;

  /// Get all translations for current language
  Map<String, String> get currentTranslations =>
      _translations[_currentLanguage] ?? _translations['en'] ?? {};
}

/// Singleton instance for easy access
final watermarkI18n = WatermarkI18n();
