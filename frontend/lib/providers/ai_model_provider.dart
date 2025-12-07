import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_model.dart';

class AiModelState {
  final List<AiModel> models;

  const AiModelState({required this.models});
}

class AiModelNotifier extends StateNotifier<AiModelState> {
  static final List<AiModel> defaultModels = [
    // Chutes models
    AiModel(id: 'chutes_1', modelName: 'zai-org/GLM-4.6', provider: AiProvider.chutes),
    AiModel(id: 'chutes_2', modelName: 'moonshotai/Kimi-K2-Thinking', provider: AiProvider.chutes),
    AiModel(id: 'chutes_3', modelName: 'MiniMaxAI/MiniMax-M2', provider: AiProvider.chutes),
    AiModel(id: 'chutes_4', modelName: 'deepseek-ai/DeepSeek-V3.1-Terminus', provider: AiProvider.chutes),
    AiModel(id: 'chutes_5', modelName: 'deepseek-ai/DeepSeek-V3.2', provider: AiProvider.chutes),
    // OpenRouter models
    AiModel(id: 'openrouter_1', modelName: 'z-ai/glm-4.6:turbo', provider: AiProvider.openrouter),
    // Google Gemini models
    AiModel(id: 'google_1', modelName: 'gemini-2.5-flash', provider: AiProvider.google),
    AiModel(id: 'google_2', modelName: 'gemini-2.5-pro', provider: AiProvider.google),
    AiModel(id: 'google_3', modelName: 'gemini-2.5-flash-lite', provider: AiProvider.google),
    // Groq models
    AiModel(id: 'groq_1', modelName: 'qwen/qwen3-32b', provider: AiProvider.groq),
    AiModel(id: 'groq_2', modelName: 'moonshotai/kimi-k2-instruct-0905', provider: AiProvider.groq),
  ];

  AiModelNotifier() : super(AiModelState(models: defaultModels));
}

final aiModelProvider = StateNotifierProvider<AiModelNotifier, AiModelState>((ref) {
  return AiModelNotifier();
});
