import 'package:flutter/material.dart';
import '../models/ai_model.dart';

/// Displays model with provider icon and short name
class ModelDisplay extends StatelessWidget {
  final AiModel model;
  final double iconSize;
  final TextStyle? textStyle;

  const ModelDisplay({
    super.key,
    required this.model,
    this.iconSize = 16,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          model.provider.iconPath,
          width: iconSize,
          height: iconSize,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            model.shortModelName,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );
  }
}
