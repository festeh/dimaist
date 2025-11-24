import 'package:flutter/material.dart';
import '../config/design_tokens.dart';
import '../models/task.dart';

class CompletedTaskWidget extends StatelessWidget {
  final Task task;
  final Function(Task) onToggleComplete;
  final Function(int) onDelete;
  final Function(Task) onEdit;

  const CompletedTaskWidget({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Dismissible(
      key: Key('dismiss-completed-${task.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(task.id!),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.xl),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Icon(
          Icons.delete_outline,
          color: colors.onError,
          size: Sizes.iconMd,
        ),
      ),
      child: Card(
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

                // Title with strikethrough
                Expanded(
                  child: Text(
                    task.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
