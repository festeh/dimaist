import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_model.dart';

class SettingsService {
  static const String _aiModelKey = 'ai_model';

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
}
