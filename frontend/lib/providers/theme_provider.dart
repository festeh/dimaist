import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/design_tokens.dart';
import '../services/settings_service.dart';

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(SettingsService.instance.themeMode);

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    await SettingsService.instance.setThemeMode(mode);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});
