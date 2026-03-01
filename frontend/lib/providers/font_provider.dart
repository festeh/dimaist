import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/design_tokens.dart';
import '../services/settings_service.dart';

class FontNotifier extends Notifier<AppFont> {
  @override
  AppFont build() => SettingsService.instance.font;

  Future<void> setFont(AppFont font) async {
    state = font;
    await SettingsService.instance.setFont(font);
  }
}

final fontProvider = NotifierProvider<FontNotifier, AppFont>(FontNotifier.new);
