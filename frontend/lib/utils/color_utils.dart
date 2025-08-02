import 'package:flutter/material.dart';

const Map<String, Color> _colorMap = {
  'gray': Colors.grey,
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

Map<String, Color> get colorMap {
  final Map<String, Color> result = Map.from(_colorMap);
  result.remove('gray');
  return result;
}

Color getColor(String colorStr) {
  return _colorMap[colorStr] ?? Colors.transparent;
}
