class Project {
  final int? id;
  final String name;
  final int order;
  final String color;
  final String? icon;

  Project({
    this.id,
    required this.name,
    required this.order,
    required this.color,
    this.icon,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      order: json['order'],
      color: json['color'] ?? 'grey',
      icon: json['icon'],
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
