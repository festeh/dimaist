import 'package:flutter/material.dart';
import '../config/design_tokens.dart';
import '../models/project.dart';
import '../models/task.dart';
import 'project_icon_widget.dart';

class CompletedTaskWidget extends StatelessWidget {
  final Task task;
  final Function(Task) onToggleComplete;
  final Function(Task) onEdit;
  final Project? project;

  const CompletedTaskWidget({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onEdit,
    this.project,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: InkWell(
        onTap: () => onEdit(task),
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: Sizes.touchTargetSmall,
                height: Sizes.touchTargetSmall,
                child: Checkbox(
                  value: true,
                  onChanged: (_) => onToggleComplete(task),
                ),
              ),

              const SizedBox(width: Spacing.sm),

              // Content
              Expanded(
                child: Row(
                  children: [
                    // Title with strikethrough
                    Expanded(
                      child: Text(
                        task.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    // Project indicator
                    if (project != null) ...[
                      const SizedBox(width: Spacing.sm),
                      ProjectIconWidget.small(
                        project: project!,
                        showName: true,
                        opacity: 0.6,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
