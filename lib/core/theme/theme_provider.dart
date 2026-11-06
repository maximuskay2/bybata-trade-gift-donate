import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

enum AppThemeMode { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  static const String _themePreferenceKey = 'theme_preference';
  static const String _glassPreferenceKey = 'glass_mode_enabled';

  AppThemeMode _themeMode = AppThemeMode.system;
  bool _glassModeEnabled = false;
  SharedPreferences? _prefs;

  AppThemeMode get themeModeSetting => _themeMode;
  ThemeMode get themeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  ThemeData get lightTheme => AppTheme.lightTheme;
  ThemeData get darkTheme => AppTheme.darkTheme;

  bool get isGlassModeEnabled => _glassModeEnabled;
  bool get isLightTheme => _themeMode == AppThemeMode.light;
  bool get isDarkTheme => _themeMode == AppThemeMode.dark;
  bool get isGlassTheme => _glassModeEnabled;
  AppThemeMode get currentTheme => _themeMode;

  // Initialize theme provider and load saved theme preference
  Future<void> initializeTheme() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadThemePreference();
  }

  // Load theme preference from shared preferences
  Future<void> _loadThemePreference() async {
    final themeName = _prefs?.getString(_themePreferenceKey) ?? 'system';
    switch (themeName) {
      case 'light':
        _themeMode = AppThemeMode.light;
        break;
      case 'dark':
        _themeMode = AppThemeMode.dark;
        break;
      case 'system':
      default:
        _themeMode = AppThemeMode.system;
    }
    _glassModeEnabled = _prefs?.getBool(_glassPreferenceKey) ?? false;
    notifyListeners();
  }

  // Save theme preference to shared preferences
  Future<void> _saveThemePreference() async {
    final themeName = _themeMode.toString().split('.').last;
    await _prefs?.setString(_themePreferenceKey, themeName);
    await _prefs?.setBool(_glassPreferenceKey, _glassModeEnabled);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      await _saveThemePreference();
      notifyListeners();
    }
  }

  Future<void> toggleGlassMode() async {
    _glassModeEnabled = !_glassModeEnabled;
    await _prefs?.setBool(_glassPreferenceKey, _glassModeEnabled);
    notifyListeners();
  }

  Future<void> setLightTheme() async {
    _glassModeEnabled = false;
    await setThemeMode(AppThemeMode.light);
  }

  Future<void> setDarkTheme() async {
    _glassModeEnabled = false;
    await setThemeMode(AppThemeMode.dark);
  }

  Future<void> setGlassTheme() async {
    _glassModeEnabled = true;
    _themeMode = AppThemeMode.dark;
    await _saveThemePreference();
    notifyListeners();
  }

  String get themeDisplayName {
    switch (_themeMode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }

  IconData get themeIcon {
    switch (_themeMode) {
      case AppThemeMode.light:
        return Icons.wb_sunny;
      case AppThemeMode.dark:
        return Icons.nights_stay;
      case AppThemeMode.system:
        return Icons.settings_suggest;
    }
  }

  List<AppThemeMode> get availableThemes => AppThemeMode.values;
}