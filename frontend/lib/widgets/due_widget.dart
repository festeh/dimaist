import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/logging_service.dart';

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
      // For date-only tasks, set to end of day (23:59:59)
      // so they're not marked as missed during the day
      final date = task.dueDate!;
      effectiveDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
      LoggingService.logger.fine(
        'Task "${task.description}" has date-only due: ${task.dueDate}, '
        'adjusted to end of day: $effectiveDate'
      );
    } else if (task.dueDatetime != null) {
      // For datetime tasks, use exact time
      effectiveDate = task.dueDatetime;
      LoggingService.logger.fine(
        'Task "${task.description}" has specific due time: $effectiveDate'
      );
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
    LoggingService.logger.fine(
      'Task "${task.description}" missed check: '
      'effectiveDate=$effectiveDate, now=$now, isMissed=$isMissed'
    );

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
