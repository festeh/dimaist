import 'package:flutter/material.dart';

const Map<String, Color> colorMap = {
  'Grey': Colors.grey,
  'Red': Colors.red,
  'Pink': Colors.pink,
  'Purple': Colors.purple,
  'Deep Purple': Colors.deepPurple,
  'Indigo': Colors.indigo,
  'Blue': Colors.blue,
  'Teal': Colors.teal,
  'Green': Colors.green,
  'Yellow': Colors.yellow,
  'Orange': Colors.orange,
  'Brown': Colors.brown,
};

/// Normalizes color name to capitalized format (e.g., 'gray' -> 'Grey')
String normalizeColor(String color) {
  final lower = color.toLowerCase();
  if (lower == 'gray' || lower == 'grey') return 'Grey';
  return lower[0].toUpperCase() + lower.substring(1);
}

Color getColor(String color) {
  return colorMap[normalizeColor(color)] ?? Colors.grey;
}
