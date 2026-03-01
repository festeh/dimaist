import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_model.dart';
import '../services/api_service.dart';
import 'service_providers.dart';

class AiModelState {
  final List<AiModel> models;

  const AiModelState({required this.models});
}

class AiModelNotifier extends Notifier<AiModelState> {
  static const String _cacheKey = 'cached_ai_models';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  ApiService get _apiService => ref.read(apiServiceProvider);

  @override
  AiModelState build() {
    _fetchModels();
    return _loadCachedModels();
  }

  static AiModelState _loadCachedModels() {
    final cached = _prefs?.getString(_cacheKey);
    if (cached != null) {
      try {
        final list = (jsonDecode(cached) as List)
            .map((e) => AiModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) return AiModelState(models: list);
      } catch (_) {}
    }
    return const AiModelState(models: [AiModel(id: 'default')]);
  }

  Future<void> _fetchModels() async {
    try {
      final models = await _apiService.fetchAiModels();
      if (models.isNotEmpty) {
        state = AiModelState(models: models);
        _saveCache(models);
      }
    } catch (_) {
      // Keep cached list on failure
    }
  }

  void _saveCache(List<AiModel> models) {
    final json = jsonEncode(models.map((m) => m.toJson()).toList());
    _prefs?.setString(_cacheKey, json);
  }

  /// Manually refresh models
  Future<void> refresh() => _fetchModels();
}

final aiModelProvider = NotifierProvider<AiModelNotifier, AiModelState>(
  AiModelNotifier.new,
);
