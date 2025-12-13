import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../models/project.dart';
import '../utils/color_utils.dart';
import '../utils/icon_utils.dart';

/// A reusable widget that displays a project's icon or colored circle.
///
/// If the project has an icon, displays the icon with the project color.
/// Otherwise, displays a colored circle.
class ProjectIconWidget extends StatelessWidget {
  final Project project;
  final double size;
  final double? opacity;
  final bool showName;
  final TextStyle? nameStyle;

  const ProjectIconWidget({
    super.key,
    required this.project,
    this.size = Sizes.iconSm,
    this.opacity,
    this.showName = false,
    this.nameStyle,
  });

  /// Creates a small project icon (for task items)
  const ProjectIconWidget.small({
    super.key,
    required this.project,
    this.opacity,
    this.showName = true,
    this.nameStyle,
  }) : size = Sizes.iconXs;

  /// Creates a medium project icon (for forms)
  const ProjectIconWidget.medium({
    super.key,
    required this.project,
    this.opacity,
    this.showName = false,
    this.nameStyle,
  }) : size = Sizes.iconMd;

  /// Creates a large project icon (for list items)
  const ProjectIconWidget.large({
    super.key,
    required this.project,
    this.opacity,
    this.showName = false,
    this.nameStyle,
  }) : size = Sizes.avatarSm * 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = getColor(project.color);
    final color = opacity != null ? baseColor.withValues(alpha: opacity!) : baseColor;

    final iconWidget = project.icon != null && project.icon!.isNotEmpty
        ? PhosphorIcon(
            getIcon(project.icon),
            size: size,
            color: color,
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          );

    if (!showName) {
      return iconWidget;
    }

    final textColor = opacity != null
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: opacity!)
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: Spacing.xs),
        Text(
          project.name,
          style: nameStyle ?? theme.textTheme.labelSmall?.copyWith(
            color: textColor,
          ),
        ),
      ],
    );
  }
}
