import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_model.dart';

class AiModelState {
  final List<AiModel> models;

  const AiModelState({required this.models});
}

class AiModelNotifier extends StateNotifier<AiModelState> {
  static final List<AiModel> defaultModels = [
    // Chutes models
    AiModel(modelName: 'zai-org/GLM-4.7-TEE', provider: AiProvider.chutes),
    AiModel(modelName: 'XiaomiMiMo/MiMo-V2-Flash', provider: AiProvider.chutes),
    AiModel(modelName: 'MiniMaxAI/MiniMax-M2.1-TEE', provider: AiProvider.chutes),
    AiModel(modelName: 'moonshotai/Kimi-K2-Thinking-TEE', provider: AiProvider.chutes),
    AiModel(modelName: 'deepseek-ai/DeepSeek-V3.1-Terminus-TEE', provider: AiProvider.chutes),
    // OpenRouter models
    AiModel(modelName: 'z-ai/glm-4.6:turbo', provider: AiProvider.openrouter),
    // Google Gemini models
    AiModel(modelName: 'gemini-2.5-flash', provider: AiProvider.google),
    // Groq models
    AiModel(modelName: 'qwen/qwen3-32b', provider: AiProvider.groq),
    AiModel(modelName: 'moonshotai/kimi-k2-instruct-0905', provider: AiProvider.groq),
  ];

  AiModelNotifier() : super(AiModelState(models: defaultModels));
}

final aiModelProvider = StateNotifierProvider<AiModelNotifier, AiModelState>((ref) {
  return AiModelNotifier();
});
