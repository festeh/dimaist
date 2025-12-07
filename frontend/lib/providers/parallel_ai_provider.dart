import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ws_message_type.dart';

/// Response status for parallel mode
enum ResponseStatus {
  pending,
  success,
  error,
  toolsPending,
}

/// Represents a single model's response in parallel mode
class ModelResponse {
  final String targetId;
  final String? content;
  final String? error;
  final List<PendingToolCall>? toolCalls;
  final double? duration;
  final ResponseStatus status;

  const ModelResponse({
    required this.targetId,
    this.content,
    this.error,
    this.toolCalls,
    this.duration,
    required this.status,
  });

  ModelResponse copyWith({
    String? targetId,
    String? content,
    String? error,
    List<PendingToolCall>? toolCalls,
    double? duration,
    ResponseStatus? status,
  }) {
    return ModelResponse(
      targetId: targetId ?? this.targetId,
      content: content ?? this.content,
      error: error ?? this.error,
      toolCalls: toolCalls ?? this.toolCalls,
      duration: duration ?? this.duration,
      status: status ?? this.status,
    );
  }
}

/// State for parallel AI mode
class ParallelAiState {
  final Set<String> selectedModelIds;
  final Map<String, ModelResponse> responses;
  final int currentPageIndex;
  final String? activeModelId; // Set when user engages with tools
  final bool isParallelMode;
  final bool allComplete;

  const ParallelAiState({
    this.selectedModelIds = const {},
    this.responses = const {},
    this.currentPageIndex = 0,
    this.activeModelId,
    this.isParallelMode = false,
    this.allComplete = false,
  });

  /// Whether we've switched to single-model mode
  bool get isSingleModelMode => activeModelId != null;

  /// List of model IDs that have responded (successfully or with error)
  List<String> get respondedModelIds => responses.entries
      .where((e) => e.value.status != ResponseStatus.pending)
      .map((e) => e.key)
      .toList();

  /// Number of models currently selected
  int get selectedCount => selectedModelIds.length;

  /// Whether multiple models are selected (enables parallel mode)
  bool get isMultipleModelsSelected => selectedModelIds.length > 1;

  ParallelAiState copyWith({
    Set<String>? selectedModelIds,
    Map<String, ModelResponse>? responses,
    int? currentPageIndex,
    String? activeModelId,
    bool? isParallelMode,
    bool? allComplete,
    bool clearActiveModel = false,
  }) {
    return ParallelAiState(
      selectedModelIds: selectedModelIds ?? this.selectedModelIds,
      responses: responses ?? this.responses,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      activeModelId: clearActiveModel ? null : (activeModelId ?? this.activeModelId),
      isParallelMode: isParallelMode ?? this.isParallelMode,
      allComplete: allComplete ?? this.allComplete,
    );
  }
}

/// Notifier for parallel AI state management
class ParallelAiNotifier extends StateNotifier<ParallelAiState> {
  ParallelAiNotifier() : super(const ParallelAiState());

  /// Toggle a model's selection for parallel mode
  void toggleModelSelection(String modelId) {
    final newSet = Set<String>.from(state.selectedModelIds);
    if (newSet.contains(modelId)) {
      newSet.remove(modelId);
    } else {
      newSet.add(modelId);
    }
    state = state.copyWith(selectedModelIds: newSet);
  }

  /// Set the selected models
  void setSelectedModels(Set<String> modelIds) {
    state = state.copyWith(selectedModelIds: modelIds);
  }

  /// Start a parallel request session
  void startParallelRequest() {
    // Initialize pending responses for all selected models
    final pendingResponses = <String, ModelResponse>{};
    for (final modelId in state.selectedModelIds) {
      pendingResponses[modelId] = ModelResponse(
        targetId: modelId,
        status: ResponseStatus.pending,
      );
    }

    state = state.copyWith(
      isParallelMode: true,
      responses: pendingResponses,
      allComplete: false,
      clearActiveModel: true,
    );
  }

  /// Add or update a model's response
  void addModelResponse(ModelResponse response) {
    final newResponses = Map<String, ModelResponse>.from(state.responses);
    newResponses[response.targetId] = response;
    state = state.copyWith(responses: newResponses);
  }

  /// Mark all models as complete
  void setAllComplete() {
    state = state.copyWith(allComplete: true);
  }

  /// Select a winning model (user engaged with its tools)
  void selectWinningModel(String targetId) {
    state = state.copyWith(
      activeModelId: targetId,
      isParallelMode: false,
    );
  }

  /// Set the current page index (for swipe navigation)
  void setCurrentPage(int index) {
    state = state.copyWith(currentPageIndex: index);
  }

  /// Reset parallel state (for new conversation)
  void reset() {
    state = state.copyWith(
      responses: const {},
      currentPageIndex: 0,
      isParallelMode: false,
      allComplete: false,
      clearActiveModel: true,
    );
  }

  /// Clear selection completely
  void clearSelection() {
    state = const ParallelAiState();
  }
}

/// Provider for parallel AI state
final parallelAiProvider =
    StateNotifierProvider<ParallelAiNotifier, ParallelAiState>((ref) {
  return ParallelAiNotifier();
});
