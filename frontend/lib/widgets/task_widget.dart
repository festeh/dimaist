import 'package:flutter/material.dart';
import 'package:dimaist/widgets/due_widget.dart';
import '../models/task.dart';

class TaskWidget extends StatelessWidget {
  final Task task;
  final Function(Task) onToggleComplete;
  final Function(int) onDelete;
  final Function(Task) onEdit;

  const TaskWidget({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => onEdit(task),
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: ListTile(
          leading: Checkbox(
            value: task.completedAt != null,
            onChanged: (value) => onToggleComplete(task),
          ),
          contentPadding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
          title: Text(
            task.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          subtitle:
              (task.dueDate != null ||
                  task.dueDatetime != null ||
                  (task.labels
                      .where((label) => label.trim().isNotEmpty)
                      .isNotEmpty))
              ? Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      if (task.recurrence != null &&
                          task.recurrence!.isNotEmpty)
                        const Icon(Icons.repeat, size: 16),
                      if (task.recurrence != null &&
                          task.recurrence!.isNotEmpty)
                        const SizedBox(width: 8),
                      if (task.dueDate != null || task.dueDatetime != null)
                        DueWidget(task: task),
                      if ((task.dueDate != null || task.dueDatetime != null) &&
                          task.labels
                              .where((label) => label.trim().isNotEmpty)
                              .isNotEmpty)
                        const SizedBox(width: 8),
                      if (task.labels
                          .where((label) => label.trim().isNotEmpty)
                          .isNotEmpty)
                        Expanded(
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: task.labels
                                .where((label) => label.trim().isNotEmpty)
                                .map(
                                  (label) => Chip(
                                    label: Text(label),
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.secondary.withAlpha(51),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                )
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => onDelete(task.id!),
          ),
        ),
      ),
    );
  }
}
