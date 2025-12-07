import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

class IncludeCompletedNotifier extends StateNotifier<bool> {
  IncludeCompletedNotifier() : super(SettingsService.instance.includeCompletedInAi);

  Future<void> setIncludeCompleted(bool value) async {
    state = value;
    await SettingsService.instance.setIncludeCompletedInAi(value);
  }
}

final includeCompletedInAiProvider = StateNotifierProvider<IncludeCompletedNotifier, bool>((ref) {
  return IncludeCompletedNotifier();
});
