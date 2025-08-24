import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class DueWidget extends StatelessWidget {
  final Task task;

  const DueWidget({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    DateTime? effectiveDate;
    if (task.dueDate != null) {
      effectiveDate = task.dueDate;
    } else if (task.dueDatetime != null) {
      effectiveDate = task.dueDatetime;
    }

    if (effectiveDate == null) {
      return const SizedBox.shrink();
    }

    String formattedDate;
    final isToday =
        effectiveDate.year == today.year &&
        effectiveDate.month == today.month &&
        effectiveDate.day == today.day;
    final isTomorrow =
        effectiveDate.year == tomorrow.year &&
        effectiveDate.month == tomorrow.month &&
        effectiveDate.day == tomorrow.day;

    if (task.dueDatetime != null) {
      if (isToday) {
        formattedDate = DateFormat.Hm().format(task.dueDatetime!);
      } else if (isTomorrow) {
        formattedDate =
            'Tomorrow at ${DateFormat.Hm().format(task.dueDatetime!)}';
      } else {
        formattedDate =
            '${DateFormat('d MMM').format(task.dueDatetime!)} at ${DateFormat.Hm().format(task.dueDatetime!)}';
      }
    } else {
      if (isToday) {
        formattedDate = 'Today';
      } else if (isTomorrow) {
        formattedDate = 'Tomorrow';
      } else {
        formattedDate = DateFormat('d MMM').format(effectiveDate);
      }
    }

    final isMissed = effectiveDate.isBefore(now);

    return Row(
      children: [
        Icon(
          Icons.calendar_today,
          size: 16,
          color: isMissed
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Text(
          formattedDate,
          style: TextStyle(
            color: isMissed
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
