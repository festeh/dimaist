class AiModel {
  final String id;
  final String displayName;
  final String apiId;

  const AiModel({
    required this.id,
    required this.displayName,
    required this.apiId,
  });

  factory AiModel.create({
    required String displayName,
    required String apiId,
  }) {
    return AiModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      displayName: displayName,
      apiId: apiId,
    );
  }

  factory AiModel.fromJson(Map<String, dynamic> json) {
    return AiModel(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      apiId: json['apiId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'apiId': apiId,
    };
  }

  AiModel copyWith({
    String? id,
    String? displayName,
    String? apiId,
  }) {
    return AiModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      apiId: apiId ?? this.apiId,
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
