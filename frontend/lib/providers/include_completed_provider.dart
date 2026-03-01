import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

class IncludeCompletedNotifier extends Notifier<bool> {
  @override
  bool build() => SettingsService.instance.includeCompletedInAi;

  Future<void> setIncludeCompleted(bool value) async {
    state = value;
    await SettingsService.instance.setIncludeCompletedInAi(value);
  }
}

final includeCompletedInAiProvider =
    NotifierProvider<IncludeCompletedNotifier, bool>(
      IncludeCompletedNotifier.new,
    );
