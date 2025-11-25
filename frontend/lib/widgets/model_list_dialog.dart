import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_model.dart';
import '../providers/ai_model_provider.dart';
import '../config/design_tokens.dart';
import 'add_edit_model_dialog.dart';

class ModelListDialog extends ConsumerWidget {
  const ModelListDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(aiModelProvider);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('AI Models'),
          IconButton(
            icon: const Icon(Icons.add),
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
                  final isSelected = model.id == modelState.selectedModelId;

                  return Card(
                    margin: const EdgeInsets.only(bottom: Spacing.sm),
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : null,
                    child: InkWell(
                      onTap: () => ref.read(aiModelProvider.notifier).selectModel(model.id),
                      borderRadius: BorderRadius.circular(Radii.sm),
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.md),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: Spacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    model.displayName,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: isSelected ? FontWeight.w600 : null,
                                    ),
                                  ),
                                  Text(
                                    model.apiId,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: Sizes.iconSm),
                              tooltip: 'Edit',
                              onPressed: () => _showAddEditDialog(context, model),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: Sizes.iconSm),
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
        const Icon(Icons.smart_toy_outlined, size: 48),
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
          icon: const Icon(Icons.add),
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
        content: Text('Are you sure you want to delete "${model.displayName}"?'),
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
