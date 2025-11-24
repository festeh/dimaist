import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_model.dart';
import '../config/design_tokens.dart';

class SettingsService {
  static const String _aiModelKey = 'ai_model';
  static const String _themeKey = 'app_theme';

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

  AiModel get aiModel {
    final modelString = _prefs?.getString(_aiModelKey);
    return AiModel.fromString(modelString ?? '') ?? AiModel.defaultModel;
  }

  Future<void> setAiModel(AiModel model) async {
    await _prefs?.setString(_aiModelKey, model.value);
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
}
