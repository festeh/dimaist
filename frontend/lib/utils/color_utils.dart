import 'package:flutter/material.dart';

enum ProjectColor {
  grey('Grey', Colors.grey),
  red('Red', Colors.red),
  pink('Pink', Colors.pink),
  purple('Purple', Colors.purple),
  deepPurple('Deep Purple', Colors.deepPurple),
  indigo('Indigo', Colors.indigo),
  blue('Blue', Colors.blue),
  cyan('Cyan', Colors.cyan),
  teal('Teal', Colors.teal),
  green('Green', Colors.green),
  lime('Lime', Colors.lime),
  yellow('Yellow', Colors.yellow),
  amber('Amber', Colors.amber),
  orange('Orange', Colors.orange),
  brown('Brown', Colors.brown);

  final String displayName;
  final Color color;
  const ProjectColor(this.displayName, this.color);

  /// Lookup map for O(1) color resolution
  static final Map<String, ProjectColor> _lookup = {
    for (final c in ProjectColor.values) ...<String, ProjectColor>{
      c.name: c,
      c.displayName.toLowerCase(): c,
    },
  };

  /// Parse from database string (e.g., "deep purple" -> deepPurple)
  static ProjectColor fromString(String value) {
    final result = _lookup[value] ?? _lookup[value.toLowerCase()];
    if (result == null) {
      debugPrint('Warning: Unknown color "$value", defaulting to grey');
      return ProjectColor.grey;
    }
    return result;
  }
}

/// Get color from string - convenience wrapper
Color getColor(String color) => ProjectColor.fromString(color).color;
