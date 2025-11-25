import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/label_provider.dart';
import '../config/design_tokens.dart';

/// Widget for selecting labels from the label storage
class LabelSelector extends ConsumerWidget {
  final List<String> selectedLabels;
  final ValueChanged<List<String>> onChanged;

  const LabelSelector({
    super.key,
    required this.selectedLabels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelState = ref.watch(labelProvider);
    final theme = Theme.of(context);

    if (labelState.isLoading) {
      return const SizedBox.shrink();
    }

    if (labelState.labels.isEmpty) {
      return Text(
        'No labels available',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Labels',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: labelState.labels.map((label) {
            final isSelected = selectedLabels.contains(label.name);
            return FilterChip(
              avatar: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: label.colorValue,
                  shape: BoxShape.circle,
                ),
              ),
              label: Text(label.name),
              selected: isSelected,
              onSelected: (selected) {
                final newLabels = List<String>.from(selectedLabels);
                if (selected) {
                  newLabels.add(label.name);
                } else {
                  newLabels.remove(label.name);
                }
                onChanged(newLabels);
              },
              selectedColor: label.colorValue.withValues(alpha: 0.3),
              checkmarkColor: theme.colorScheme.onSurface,
            );
          }).toList(),
        ),
      ],
    );
  }
}
