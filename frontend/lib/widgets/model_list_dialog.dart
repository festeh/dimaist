import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/ai_model.dart';
import '../providers/ai_model_provider.dart';
import '../providers/parallel_ai_provider.dart';
import '../config/design_tokens.dart';
import 'add_edit_model_dialog.dart';

class ModelListDialog extends ConsumerWidget {
  const ModelListDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(aiModelProvider);
    final parallelState = ref.watch(parallelAiProvider);
    final theme = Theme.of(context);
    final selectedCount = parallelState.selectedModelIds.length;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('AI Models'),
          IconButton(
            icon: PhosphorIcon(PhosphorIcons.plus(), size: Sizes.iconSm),
            tooltip: 'Add Model',
            onPressed: () => _showAddEditDialog(context, null),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: modelState.models.isEmpty
            ? _buildEmptyState(context)
            : ListView.builder(
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    model.modelName,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: isSelected ? FontWeight.w600 : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      Image.asset(
                                        model.provider.iconPath,
                                        width: 14,
                                        height: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        model.provider.displayName,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: PhosphorIcon(PhosphorIcons.pencilSimple(), size: Sizes.iconSm),
                              tooltip: 'Edit',
                              onPressed: () => _showAddEditDialog(context, model),
                            ),
                            // Hide delete button if only one model remains
                            if (modelState.models.length > 1)
                              IconButton(
                                icon: PhosphorIcon(PhosphorIcons.trash(), size: Sizes.iconSm),
                                tooltip: 'Delete',
                                onPressed: () => _confirmDelete(context, ref, model),
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

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhosphorIcon(PhosphorIcons.robot(), size: 48),
        const SizedBox(height: Spacing.md),
        Text(
          'No models configured',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          'Add your first AI model to get started',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: Spacing.lg),
        ElevatedButton.icon(
          onPressed: () => _showAddEditDialog(context, null),
          icon: PhosphorIcon(PhosphorIcons.plus(), size: Sizes.iconSm),
          label: const Text('Add Model'),
        ),
      ],
    );
  }

  void _showAddEditDialog(BuildContext context, AiModel? model) {
    showDialog(
      context: context,
      builder: (context) => AddEditModelDialog(model: model),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AiModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete "${model.modelName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(aiModelProvider.notifier).deleteModel(model.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
