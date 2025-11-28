import 'package:shared_preferences/shared_preferences.dart';
import '../config/design_tokens.dart';

class SettingsService {
  static const String _themeKey = 'app_theme';
  static const String _fontKey = 'app_font';
  static const String _asrLanguageKey = 'asr_language';

  static SettingsService? _instance;
  SharedPreferences? _prefs;

  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }

  SettingsService._();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  AppThemeMode get themeMode {
    final themeString = _prefs?.getString(_themeKey);
    if (themeString == null) return AppThemeMode.midnight;
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == themeString,
      orElse: () => AppThemeMode.midnight,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _prefs?.setString(_themeKey, mode.name);
  }

  AppFont get font {
    final fontString = _prefs?.getString(_fontKey);
    if (fontString == null) return AppFont.inter;
    return AppFont.values.firstWhere(
      (font) => font.name == fontString,
      orElse: () => AppFont.inter,
    );
  }

  Future<void> setFont(AppFont font) async {
    await _prefs?.setString(_fontKey, font.name);
  }

  String get asrLanguage {
    return _prefs?.getString(_asrLanguageKey) ?? 'auto';
  }

  Future<void> setAsrLanguage(String language) async {
    await _prefs?.setString(_asrLanguageKey, language);
  }
}
