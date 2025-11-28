import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/design_tokens.dart';
import '../services/settings_service.dart';

class FontNotifier extends StateNotifier<AppFont> {
  FontNotifier() : super(SettingsService.instance.font);

  Future<void> setFont(AppFont font) async {
    state = font;
    await SettingsService.instance.setFont(font);
  }
}

final fontProvider = StateNotifierProvider<FontNotifier, AppFont>((ref) {
  return FontNotifier();
});
