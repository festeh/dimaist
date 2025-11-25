import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/label.dart';
import '../providers/label_provider.dart';
import '../config/design_tokens.dart';

class LabelListDialog extends ConsumerStatefulWidget {
  const LabelListDialog({super.key});

  @override
  ConsumerState<LabelListDialog> createState() => _LabelListDialogState();
}

class _LabelListDialogState extends ConsumerState<LabelListDialog> {
  String? _editingLabelId;
  final _nameController = TextEditingController();
  String _selectedColor = LabelColors.blue;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startEditing(Label label) {
    setState(() {
      _editingLabelId = label.id;
      _nameController.text = label.name;
      _selectedColor = label.color;
    });
  }

  void _startAdding() {
    setState(() {
      _editingLabelId = 'new';
      _nameController.text = '';
      _selectedColor = LabelColors.blue;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingLabelId = null;
      _nameController.clear();
    });
  }

  void _saveLabel() {
    final name = _nameController.text.trim().toLowerCase();
    if (name.isEmpty) return;

    if (_editingLabelId == 'new') {
      final label = Label.create(name: name, color: _selectedColor);
      ref.read(labelProvider.notifier).addLabel(label);
    } else if (_editingLabelId != null) {
      final label = Label(id: _editingLabelId!, name: name, color: _selectedColor);
      ref.read(labelProvider.notifier).updateLabel(label);
    }

    _cancelEditing();
  }

  @override
  Widget build(BuildContext context) {
    final labelState = ref.watch(labelProvider);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Labels'),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Label',
            onPressed: _editingLabelId == null ? _startAdding : null,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_editingLabelId == 'new') _buildEditRow(null, theme),
            if (labelState.labels.isEmpty && _editingLabelId == null)
              _buildEmptyState(context)
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: labelState.labels.length,
                  itemBuilder: (context, index) {
                    final label = labelState.labels[index];
                    if (_editingLabelId == label.id) {
                      return _buildEditRow(label, theme);
                    }
                    return _buildLabelRow(label, theme);
                  },
                ),
              ),
          ],
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

  Widget _buildLabelRow(Label label, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: label.colorValue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                label.name,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: Sizes.iconSm),
              tooltip: 'Edit',
              onPressed: () => _startEditing(label),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: Sizes.iconSm),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditRow(Label? label, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Label name',
                      hintText: 'e.g., urgent, work',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _saveLabel(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: LabelColors.all.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: LabelColors.parse(color),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: Spacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _cancelEditing,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: Spacing.sm),
                FilledButton(
                  onPressed: _saveLabel,
                  child: Text(label == null ? 'Add' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.label_outline, size: 48),
        const SizedBox(height: Spacing.md),
        Text(
          'No labels yet',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          'Add your first label to get started',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: Spacing.lg),
        ElevatedButton.icon(
          onPressed: _startAdding,
          icon: const Icon(Icons.add),
          label: const Text('Add Label'),
        ),
      ],
    );
  }

  void _confirmDelete(Label label) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Label'),
        content: Text('Are you sure you want to delete "${label.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(labelProvider.notifier).deleteLabel(label.id);
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
