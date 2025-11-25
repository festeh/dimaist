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

  AiModel? get selectedModel {
    if (selectedModelId == null || models.isEmpty) return null;
    try {
      return models.firstWhere((m) => m.id == selectedModelId);
    } catch (_) {
      return models.isNotEmpty ? models.first : null;
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
        // Invalid JSON, start fresh
        models = [];
      }
    }

    state = AiModelState(
      models: models,
      selectedModelId: selectedId,
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

  Future<void> deleteModel(String modelId) async {
    final newModels = state.models.where((m) => m.id != modelId).toList();

    // Handle deletion of selected model
    String? newSelectedId = state.selectedModelId;
    if (state.selectedModelId == modelId) {
      newSelectedId = newModels.isNotEmpty ? newModels.first.id : null;
    }

    state = AiModelState(
      models: newModels,
      selectedModelId: newSelectedId,
    );

    await _saveModels();
    await _saveSelectedId(newSelectedId);
  }

  Future<void> selectModel(String modelId) async {
    state = state.copyWith(selectedModelId: modelId);
    await _saveSelectedId(modelId);
  }
}

final aiModelProvider = StateNotifierProvider<AiModelNotifier, AiModelState>((ref) {
  return AiModelNotifier();
});
