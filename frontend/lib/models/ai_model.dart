enum AiModel {
  deepseekR1('chutes/deepseek-ai/DeepSeek-R1'),
  qwen3235B('chutes/Qwen/Qwen3-235B-A22B'),
  gptOss120b('chutes/openai/gpt-oss-120b'),
  gptOss120bOpenrouter('openrouter/openai/gpt-oss-120b:nitro'),
  gptOss20b('chutes/openai/gpt-oss-20b'),
  deepseekV31('chutes/deepseek-ai/DeepSeek-V3.1'),
  deepseekV31Openrouter('openrouter/deepseek/deepseek-chat-v3.1:nitro'),
  glm45('chutes/zai-org/GLM-4.5-FP8');

  const AiModel(this.value);

  final String value;

  static AiModel get defaultModel => AiModel.deepseekV31;

  static AiModel? fromString(String value) {
    for (AiModel model in AiModel.values) {
      if (model.value == value) {
        return model;
      }
    }
    return null;
  }

  static List<String> get allValues =>
      AiModel.values.map((e) => e.value).toList();
}
