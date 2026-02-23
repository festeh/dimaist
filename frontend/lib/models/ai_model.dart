class AiModel {
  final String id;
  final String ownedBy;

  const AiModel({
    required this.id,
    this.ownedBy = '',
  });

  /// Short display name (part after last /)
  String get displayName {
    final slashIndex = id.lastIndexOf('/');
    if (slashIndex >= 0 && slashIndex < id.length - 1) {
      return id.substring(slashIndex + 1);
    }
    return id;
  }

  /// Parse from /v1/models response item
  factory AiModel.fromModelsResponse(Map<String, dynamic> json) {
    return AiModel(
      id: json['id'] as String,
      ownedBy: json['owned_by'] as String? ?? '',
    );
  }

  factory AiModel.fromJson(Map<String, dynamic> json) {
    return AiModel(
      id: json['id'] as String,
      ownedBy: json['ownedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownedBy': ownedBy,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AiModel(id: $id, ownedBy: $ownedBy)';
}
