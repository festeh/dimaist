import 'package:flutter/material.dart';
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
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => onEdit(task),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
          leading: Checkbox(
            value: task.completedAt != null,
            onChanged: (value) => onToggleComplete(task),
          ),
          title: Text(
            task.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => onDelete(task.id!),
          ),
        ),
      ),
    );
  }
}
