import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../utils/color_utils.dart';
import '../utils/icon_utils.dart';
import 'due_widget.dart';

class TaskWidget extends StatelessWidget {
  final Task task;
  final Function(Task) onToggleComplete;
  final Function(Task) onEdit;
  final bool showDragHandle;
  final int? dragIndex;
  final bool showCheckbox;
  final Project? project;

  const TaskWidget({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onEdit,
    this.showDragHandle = false,
    this.dragIndex,
    this.showCheckbox = true,
    this.project,
  });

  List<String> get _nonEmptyLabels =>
      task.labels.where((l) => l.trim().isNotEmpty).toList();

  bool get _hasMetadata =>
      task.due != null ||
      task.recurrence != null ||
      _nonEmptyLabels.isNotEmpty;

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
              // Drag handle (conditional)
              if (showDragHandle && dragIndex != null) ...[
                ReorderableDragStartListener(
                  index: dragIndex!,
                  child: PhosphorIcon(
                    PhosphorIcons.dotsSixVertical(),
                    size: Sizes.iconSm,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
              ],

              // Checkbox
              if (showCheckbox) ...[
                SizedBox(
                  width: Sizes.touchTargetSmall,
                  height: Sizes.touchTargetSmall,
                  child: Checkbox(
                    value: false,
                    onChanged: (_) => onToggleComplete(task),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
              ],

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title row with project indicator
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        if (project != null) ...[
                          const SizedBox(width: Spacing.sm),
                          _buildProjectIndicator(context),
                        ],
                      ],
                    ),

                    // Metadata row
                    if (_hasMetadata) ...[
                      const SizedBox(height: Spacing.xs),
                      _buildMetadataRow(context),
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

  Widget _buildProjectIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (project!.icon != null && project!.icon!.isNotEmpty)
          PhosphorIcon(
            getIcon(project!.icon),
            size: Sizes.iconXs,
            color: getColor(project!.color),
          )
        else
          Container(
            width: Sizes.iconXs,
            height: Sizes.iconXs,
            decoration: BoxDecoration(
              color: getColor(project!.color),
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: Spacing.xs),
        Text(
          project!.name,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataRow(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        // Recurrence indicator
        if (task.recurrence != null && task.recurrence!.isNotEmpty) ...[
          PhosphorIcon(
            PhosphorIcons.arrowsClockwise(),
            size: Sizes.iconXs,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.sm),
        ],

        // Due date
        if (task.due != null) ...[
          DueWidget(task: task),
          const SizedBox(width: Spacing.sm),
        ],

        // Labels as compact text
        if (_nonEmptyLabels.isNotEmpty)
          Expanded(
            child: Text(
              _nonEmptyLabels.length <= 5
                  ? _nonEmptyLabels.join(', ')
                  : '${_nonEmptyLabels.take(5).join(', ')} +${_nonEmptyLabels.length - 5}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.secondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
