import 'package:flutter/material.dart';
import '../models/ai_model.dart';

/// Displays model short name
class ModelDisplay extends StatelessWidget {
  final AiModel model;
  final TextStyle? textStyle;

  const ModelDisplay({
    super.key,
    required this.model,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      model.displayName,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
  }
}
