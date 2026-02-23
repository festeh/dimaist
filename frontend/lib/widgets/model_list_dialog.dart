import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_model.dart';
import '../providers/ai_model_provider.dart';
import '../providers/parallel_ai_provider.dart';
import '../config/design_tokens.dart';

class ModelListDialog extends ConsumerWidget {
  const ModelListDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(aiModelProvider);
    final parallelState = ref.watch(parallelAiProvider);
    final theme = Theme.of(context);
    final selectedCount = parallelState.selectedModelIds.length;

    // Group models by ownedBy
    final grouped = <String, List<AiModel>>{};
    for (final model in modelState.models) {
      grouped.putIfAbsent(model.ownedBy, () => []).add(model);
    }
    final providers = grouped.keys.toList()..sort();

    return AlertDialog(
      title: const Text('AI Models'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: providers.fold<int>(0, (sum, p) => sum + 1 + grouped[p]!.length),
          itemBuilder: (context, index) {
            // Walk through providers and their models
            var remaining = index;
            for (final provider in providers) {
              if (remaining == 0) {
                // Provider header
                final label = provider.isNotEmpty
                    ? provider[0].toUpperCase() + provider.substring(1)
                    : 'Other';
                return Padding(
                  padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.xs, left: Spacing.sm),
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              remaining--;

              final models = grouped[provider]!;
              if (remaining < models.length) {
                final model = models[remaining];
                final isSelected = parallelState.selectedModelIds.contains(model.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: Spacing.xs),
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : null,
                  child: InkWell(
                    onTap: () => ref.read(parallelAiProvider.notifier).toggleModelSelection(model.id),
                    borderRadius: BorderRadius.circular(Radii.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.md),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => ref.read(parallelAiProvider.notifier).toggleModelSelection(model.id),
                          ),
                          const SizedBox(width: Spacing.sm),
                          Expanded(
                            child: Text(
                              model.displayName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.w600 : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              remaining -= models.length;
            }
            return const SizedBox.shrink();
          },
        ),
      ),
      actions: [
        if (selectedCount == 0)
          Text(
            'Select at least one model',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
