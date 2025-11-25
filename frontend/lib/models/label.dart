import 'package:flutter/material.dart';

class Label {
  final String id;
  final String name;
  final String color; // hex color string like '#58A6FF'

  const Label({
    required this.id,
    required this.name,
    required this.color,
  });

  /// Parse hex color string to Color
  Color get colorValue {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  factory Label.create({
    required String name,
    required String color,
  }) {
    return Label(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.toLowerCase().trim(),
      color: color,
    );
  }

  factory Label.fromJson(Map<String, dynamic> json) {
    return Label(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }

  Label copyWith({
    String? id,
    String? name,
    String? color,
  }) {
    return Label(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Label && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Label(id: $id, name: $name, color: $color)';
}

/// Available colors for labels
class LabelColors {
  static const String blue = '#58A6FF';
  static const String green = '#3FB950';
  static const String red = '#F85149';
  static const String yellow = '#D29922';
  static const String purple = '#A371F7';
  static const String grey = '#8B949E';

  static const List<String> all = [blue, green, red, yellow, purple, grey];

  /// Parse hex color string to Color
  static Color parse(String hex) {
    final cleanHex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleanHex', radix: 16));
  }
}
