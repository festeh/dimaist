class Project {
  final int? id;
  final String name;
  final int order;
  final String color;
  final String? icon;

  /// Set when the server reports this row as soft-deleted via /sync.
  /// Not persisted to the local DB — used only by the sync apply step.
  final DateTime? deletedAt;

  Project({
    this.id,
    required this.name,
    required this.order,
    required this.color,
    this.icon,
    this.deletedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    final deletedRaw = json['deleted_at'] as String?;
    return Project(
      id: json['id'],
      name: json['name'],
      order: json['order'],
      color: json['color'] ?? 'grey',
      icon: json['icon'],
      deletedAt: deletedRaw != null ? DateTime.tryParse(deletedRaw) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
      'color': color,
      if (icon != null) 'icon': icon,
    };
  }

  Project copyWith({
    int? id,
    String? name,
    int? order,
    String? color,
    String? icon,
    bool clearIcon = false,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      color: color ?? this.color,
      icon: clearIcon ? null : (icon ?? this.icon),
    );
  }
}
