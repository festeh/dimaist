enum AiProvider {
  chutes,
  openrouter;

  String get displayName {
    switch (this) {
      case AiProvider.chutes:
        return 'Chutes';
      case AiProvider.openrouter:
        return 'OpenRouter';
    }
  }
}

class AiModel {
  final String id;
  final String modelName;
  final AiProvider provider;

  const AiModel({
    required this.id,
    required this.modelName,
    required this.provider,
  });

  /// Display name shown in UI (provider: model)
  String get displayName => '${provider.displayName}: $modelName';

  /// API identifier sent to backend
  String get apiId => modelName;

  factory AiModel.create({
    required String modelName,
    required AiProvider provider,
  }) {
    return AiModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      modelName: modelName,
      provider: provider,
    );
  }

  factory AiModel.fromJson(Map<String, dynamic> json) {
    // Handle legacy format (displayName + apiId)
    if (json.containsKey('displayName') && !json.containsKey('modelName')) {
      return AiModel(
        id: json['id'] as String,
        modelName: json['apiId'] as String? ?? json['displayName'] as String,
        provider: AiProvider.chutes,
      );
    }
    return AiModel(
      id: json['id'] as String,
      modelName: json['modelName'] as String,
      provider: AiProvider.values.firstWhere(
        (p) => p.name == json['provider'],
        orElse: () => AiProvider.chutes,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'modelName': modelName,
      'provider': provider.name,
    };
  }

  AiModel copyWith({
    String? id,
    String? modelName,
    AiProvider? provider,
  }) {
    return AiModel(
      id: id ?? this.id,
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
