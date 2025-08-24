class Project {
  final int? id;
  final String name;
  final int order;
  final String color;

  Project({
    this.id,
    required this.name,
    required this.order,
    required this.color,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      order: json['order'],
      color: json['color'] ?? 'grey',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'order': order, 'color': color};
  }

  Project copyWith({
    int? id,
    String? name,
    int? order,
    bool? isInbox,
    String? color,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      color: color ?? this.color,
    );
  }
}
