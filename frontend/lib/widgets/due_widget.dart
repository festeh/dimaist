import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/task.dart';

class DueWidget extends StatelessWidget {
  final Task task;

  const DueWidget({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    if (task.due == null) {
      return const SizedBox.shrink();
    }

    DateTime effectiveDate;
    if (task.hasTime) {
      // For datetime tasks, use exact time
      effectiveDate = task.due!;
    } else {
      // For date-only tasks, set to end of day (23:59:59)
      // so they're not marked as missed during the day
      final date = task.due!;
      effectiveDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
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

    if (task.hasTime) {
      final localDatetime = task.due!.toLocal();
      if (isToday) {
        formattedDate = DateFormat.Hm().format(localDatetime);
      } else if (isTomorrow) {
        formattedDate =
            'Tomorrow at ${DateFormat.Hm().format(localDatetime)}';
      } else {
        formattedDate =
            '${DateFormat('d MMM').format(localDatetime)} at ${DateFormat.Hm().format(localDatetime)}';
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
        PhosphorIcon(
          PhosphorIcons.calendar(),
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
