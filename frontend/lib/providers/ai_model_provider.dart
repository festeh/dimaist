import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_model.dart';

class AiModelState {
  final List<AiModel> models;
  final String? selectedModelId;
  final bool isLoading;

  const AiModelState({
    required this.models,
    this.selectedModelId,
    this.isLoading = false,
  });

  /// Returns the selected model. Always returns a model since we guarantee at least one exists.
  AiModel get selectedModel {
    if (models.isEmpty) {
      // This should never happen, but fallback to a default
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
    bool? isLoading,
    bool clearSelectedModel = false,
  }) {
    return AiModelState(
      models: models ?? this.models,
      selectedModelId: clearSelectedModel ? null : (selectedModelId ?? this.selectedModelId),
      isLoading: isLoading ?? this.isLoading,
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
  ];

  SharedPreferences? _prefs;

  AiModelNotifier() : super(const AiModelState(models: [], isLoading: true)) {
    _loadModels();
  }

  Future<void> _loadModels() async {
    _prefs = await SharedPreferences.getInstance();
    final modelsJson = _prefs?.getString(_modelsKey);
    final selectedId = _prefs?.getString(_selectedKey);

    List<AiModel> models = [];
    if (modelsJson != null && modelsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(modelsJson);
        models = decoded.map((e) => AiModel.fromJson(e)).toList();
      } catch (_) {
        // Invalid JSON, use defaults
        models = List.from(_defaultModels);
      }
    } else {
      // No saved models, use defaults
      models = List.from(_defaultModels);
    }

    state = AiModelState(
      models: models,
      selectedModelId: selectedId ?? (models.isNotEmpty ? models.first.id : null),
      isLoading: false,
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
