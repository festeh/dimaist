import 'package:flutter/material.dart';
import '../config/design_tokens.dart';

/// Default reminder options available for selection
const reminderOptions = [
  '5 minutes',
  '30 minutes',
  '1 hour',
  '12 hours',
  '1 day',
  '1 week',
];

/// A widget for selecting reminder times using filter chips
class ReminderPicker extends StatelessWidget {
  final List<String> selectedReminders;
  final ValueChanged<List<String>> onChanged;

  const ReminderPicker({
    super.key,
    required this.selectedReminders,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reminders',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: reminderOptions.map((reminder) {
            return FilterChip(
              label: Text(reminder),
              selected: selectedReminders.contains(reminder),
              onSelected: (selected) {
                final newReminders = List<String>.from(selectedReminders);
                if (selected) {
                  newReminders.add(reminder);
                } else {
                  newReminders.remove(reminder);
                }
                onChanged(newReminders);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Converts a reminder string to a Duration
Duration reminderStringToDuration(String reminderString) {
  final parts = reminderString.split(' ');
  final value = int.parse(parts[0]);
  final unit = parts[1];

  switch (unit) {
    case 'minutes':
      return Duration(minutes: value);
    case 'hour':
      return Duration(hours: value);
    case 'hours':
      return Duration(hours: value);
    case 'day':
      return Duration(days: value);
    case 'week':
      return Duration(days: value * 7);
    default:
      return Duration.zero;
  }
}

/// Converts a reminder DateTime and due date to a reminder string
String reminderDateTimeToString(DateTime reminder, DateTime dueDate) {
  final difference = dueDate.difference(reminder);
  if (difference.inDays >= 7) {
    return '${difference.inDays ~/ 7} week';
  } else if (difference.inDays > 0) {
    return '${difference.inDays} day';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} hour';
  } else if (difference.inMinutes >= 30) {
    return '30 minutes';
  } else {
    return '5 minutes';
  }
}
