import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

enum AsrLanguage {
  auto('auto', 'Auto'),
  ru('ru', 'Russian'),
  en('en', 'English');

  final String code;
  final String displayName;

  const AsrLanguage(this.code, this.displayName);

  static AsrLanguage fromCode(String code) {
    return AsrLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AsrLanguage.auto,
    );
  }
}

class AsrLanguageNotifier extends StateNotifier<AsrLanguage> {
  AsrLanguageNotifier()
      : super(AsrLanguage.fromCode(SettingsService.instance.asrLanguage));

  Future<void> setLanguage(AsrLanguage language) async {
    state = language;
    await SettingsService.instance.setAsrLanguage(language.code);
  }
}

final asrLanguageProvider =
    StateNotifierProvider<AsrLanguageNotifier, AsrLanguage>((ref) {
  return AsrLanguageNotifier();
});
