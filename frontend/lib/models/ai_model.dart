enum AiProvider {
  kimi,
  openrouter,
  google,
  groq;

  String get displayName {
    switch (this) {
      case AiProvider.kimi:
        return 'Kimi';
      case AiProvider.openrouter:
        return 'OpenRouter';
      case AiProvider.google:
        return 'Google';
      case AiProvider.groq:
        return 'Groq';
    }
  }

  String get iconPath {
    switch (this) {
      case AiProvider.kimi:
        return 'assets/icons/kimi.png';
      case AiProvider.openrouter:
        return 'assets/icons/openrouter.png';
      case AiProvider.google:
        return 'assets/icons/google.png';
      case AiProvider.groq:
        return 'assets/icons/groq.png';
    }
  }
}

class AiModel {
  final String modelName;
  final AiProvider provider;

  const AiModel({
    required this.modelName,
    required this.provider,
  });

  /// Stable ID derived from provider and model name
  String get id => '${provider.name}:$modelName';

  /// Display name shown in UI (provider: model)
  String get displayName => '${provider.displayName}: $modelName';

  /// Short model name (part after last /)
  String get shortModelName => modelName.split('/').last;

  /// API identifier sent to backend
  String get apiId => modelName;

  factory AiModel.fromJson(Map<String, dynamic> json) {
    return AiModel(
      modelName: json['modelName'] as String,
      provider: AiProvider.values.firstWhere(
        (p) => p.name == json['provider'],
        orElse: () => AiProvider.kimi,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'modelName': modelName,
      'provider': provider.name,
    };
  }

  AiModel copyWith({
    String? modelName,
    AiProvider? provider,
  }) {
    return AiModel(
      modelName: modelName ?? this.modelName,
      provider: provider ?? this.provider,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AiModel(id: $id, displayName: $displayName, apiId: $apiId)';
}
