import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/design_tokens.dart';

/// Compact date+time field for schedule sections
class DateTimeField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;

  const DateTimeField({
    super.key,
    required this.label,
    required this.date,
    required this.time,
    required this.onDateTap,
    required this.onTimeTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Row(
          children: [
            InkWell(
              onTap: onDateTap,
              child: Text(
                date != null
                    ? DateFormat('M/d').format(date!)
                    : 'Date',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: date != null ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              ' @ ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            InkWell(
              onTap: onTimeTap,
              child: Text(
                time != null
                    ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
                    : 'Time',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: time != null ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
