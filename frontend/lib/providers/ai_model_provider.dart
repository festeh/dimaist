import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_model.dart';

class AiModelState {
  final List<AiModel> models;
  final String? selectedModelId;

  const AiModelState({
    required this.models,
    this.selectedModelId,
  });

  /// Returns the selected model - always valid after init
  AiModel get selectedModel {
    if (models.isEmpty) {
      return AiModelNotifier._defaultModels.first;
    }
    if (selectedModelId == null) {
      return models.first;
    }
    try {
      return models.firstWhere((m) => m.id == selectedModelId);
    } catch (_) {
      return models.first;
    }
  }

  AiModelState copyWith({
    List<AiModel>? models,
    String? selectedModelId,
    bool clearSelectedModel = false,
  }) {
    return AiModelState(
      models: models ?? this.models,
      selectedModelId: clearSelectedModel ? null : (selectedModelId ?? this.selectedModelId),
    );
  }
}

class AiModelNotifier extends StateNotifier<AiModelState> {
  static const String _modelsKey = 'ai_models_list';
  static const String _selectedKey = 'ai_model_selected_id';

  static final List<AiModel> _defaultModels = [
    AiModel(id: 'default_1', modelName: 'zai-org/GLM-4.6', provider: AiProvider.chutes),
    AiModel(id: 'default_2', modelName: 'moonshotai/Kimi-K2-Thinking', provider: AiProvider.chutes),
    AiModel(id: 'default_3', modelName: 'MiniMaxAI/MiniMax-M2', provider: AiProvider.chutes),
    AiModel(id: 'default_4', modelName: 'deepseek-ai/DeepSeek-V3.1-Terminus', provider: AiProvider.chutes),
    AiModel(id: 'default_5', modelName: 'z-ai/glm-4.6:turbo', provider: AiProvider.openrouter),
    // Google Gemini free tier models
    AiModel(id: 'default_6', modelName: 'gemini-2.5-flash', provider: AiProvider.google),
    AiModel(id: 'default_7', modelName: 'gemini-2.5-pro', provider: AiProvider.google),
    AiModel(id: 'default_8', modelName: 'gemini-2.5-flash-lite', provider: AiProvider.google),
  ];

  static SharedPreferences? _prefs;

  /// Must be called before app starts
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  AiModelNotifier() : super(_loadInitialState());

  static AiModelState _loadInitialState() {
    final modelsJson = _prefs?.getString(_modelsKey);
    final selectedId = _prefs?.getString(_selectedKey);

    List<AiModel> models = [];
    if (modelsJson != null && modelsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(modelsJson);
        models = decoded.map((e) => AiModel.fromJson(e)).toList();
      } catch (_) {
        models = List.from(_defaultModels);
      }
    } else {
      models = List.from(_defaultModels);
    }

    // Validate selectedId exists in models
    String? validSelectedId;
    if (selectedId != null && models.any((m) => m.id == selectedId)) {
      validSelectedId = selectedId;
    } else if (models.isNotEmpty) {
      validSelectedId = models.first.id;
    }

    return AiModelState(
      models: models,
      selectedModelId: validSelectedId,
    );
  }

  Future<void> _saveModels() async {
    final json = jsonEncode(state.models.map((m) => m.toJson()).toList());
    await _prefs?.setString(_modelsKey, json);
  }

  Future<void> _saveSelectedId(String? id) async {
    if (id != null) {
      await _prefs?.setString(_selectedKey, id);
    } else {
      await _prefs?.remove(_selectedKey);
    }
  }

  Future<void> addModel(AiModel model) async {
    final newModels = [...state.models, model];
    final shouldAutoSelect = state.models.isEmpty;

    state = state.copyWith(
      models: newModels,
      selectedModelId: shouldAutoSelect ? model.id : null,
    );

    await _saveModels();
    if (shouldAutoSelect) {
      await _saveSelectedId(model.id);
    }
  }

  Future<void> updateModel(AiModel model) async {
    final newModels = state.models.map((m) => m.id == model.id ? model : m).toList();
    state = state.copyWith(models: newModels);
    await _saveModels();
  }

  Future<bool> deleteModel(String modelId) async {
    // Prevent deleting the last model
    if (state.models.length <= 1) {
      return false;
    }

    final newModels = state.models.where((m) => m.id != modelId).toList();

    // Handle deletion of selected model
    String? newSelectedId = state.selectedModelId;
    if (state.selectedModelId == modelId) {
      newSelectedId = newModels.first.id;
    }

    state = AiModelState(
      models: newModels,
      selectedModelId: newSelectedId,
    );

    await _saveModels();
    await _saveSelectedId(newSelectedId);
    return true;
  }

  Future<void> selectModel(String modelId) async {
    state = state.copyWith(selectedModelId: modelId);
    await _saveSelectedId(modelId);
  }
}

final aiModelProvider = StateNotifierProvider<AiModelNotifier, AiModelState>((ref) {
  return AiModelNotifier();
});
