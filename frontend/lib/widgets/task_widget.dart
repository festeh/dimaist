import 'package:flutter/material.dart';
import '../config/design_tokens.dart';
import '../models/task.dart';
import 'due_widget.dart';

class TaskWidget extends StatelessWidget {
  final Task task;
  final Function(Task) onToggleComplete;
  final Function(Task) onEdit;
  final bool showDragHandle;
  final int? dragIndex;

  const TaskWidget({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onEdit,
    this.showDragHandle = false,
    this.dragIndex,
  });

  List<String> get _nonEmptyLabels =>
      task.labels.where((l) => l.trim().isNotEmpty).toList();

  bool get _hasMetadata =>
      task.dueDate != null ||
      task.dueDatetime != null ||
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
                  child: Icon(
                    Icons.drag_handle,
                    size: Sizes.iconSm,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
              ],

              // Checkbox
              SizedBox(
                width: Sizes.touchTargetSmall,
                height: Sizes.touchTargetSmall,
                child: Checkbox(
                  value: false,
                  onChanged: (_) => onToggleComplete(task),
                ),
              ),

              const SizedBox(width: Spacing.sm),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      task.description,
                      style: theme.textTheme.bodyLarge,
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

  Widget _buildMetadataRow(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        // Recurrence indicator
        if (task.recurrence != null && task.recurrence!.isNotEmpty) ...[
          Icon(
            Icons.repeat,
            size: Sizes.iconXs,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.sm),
        ],

        // Due date
        if (task.dueDate != null || task.dueDatetime != null) ...[
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
