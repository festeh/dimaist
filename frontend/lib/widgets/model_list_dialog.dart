import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return AlertDialog(
      title: const Text('AI Models'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: modelState.models.length,
          itemBuilder: (context, index) {
            final model = modelState.models[index];
            final isSelected = parallelState.selectedModelIds.contains(model.id);

            return Card(
              margin: const EdgeInsets.only(bottom: Spacing.sm),
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
                      Image.asset(
                        model.provider.iconPath,
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          model.modelName,
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
