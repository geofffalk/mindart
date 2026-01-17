import 'package:shared_preferences/shared_preferences.dart';
import '../models/visual_theme.dart';

/// Service for managing app settings with local persistence
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;
  
  static const String _keyGender = 'gender_preference';
  static const String _keyTheme = 'visual_theme';
  static const String _defaultGender = 'woman';
  static const AppVisualTheme _defaultTheme = AppVisualTheme.blueNeon;

  /// Initialize the settings service - must be called before use
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get the current gender preference ('man' or 'woman')
  String getGender() {
    return _prefs?.getString(_keyGender) ?? _defaultGender;
  }

  /// Set the gender preference
  Future<void> setGender(String gender) async {
    if (gender != 'man' && gender != 'woman') {
      throw ArgumentError('Gender must be either "man" or "woman"');
    }
    await _prefs?.setString(_keyGender, gender);
  }

  /// Get the current visual theme
  AppVisualTheme getTheme() {
    final themeName = _prefs?.getString(_keyTheme);
    if (themeName == null) return _defaultTheme;
    try {
      return AppVisualTheme.values.byName(themeName);
    } catch (_) {
      return _defaultTheme;
    }
  }

  /// Set the visual theme
  Future<void> setTheme(AppVisualTheme theme) async {
    await _prefs?.setString(_keyTheme, theme.name);
  }
}
