import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_model.dart';
import '../providers/ai_model_provider.dart';

class AddEditModelDialog extends ConsumerStatefulWidget {
  final AiModel? model;

  const AddEditModelDialog({super.key, this.model});

  @override
  ConsumerState<AddEditModelDialog> createState() => _AddEditModelDialogState();
}

class _AddEditModelDialogState extends ConsumerState<AddEditModelDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _modelNameController;
  late AiProvider _selectedProvider;

  bool get isEditing => widget.model != null;

  @override
  void initState() {
    super.initState();
    _modelNameController = TextEditingController(text: widget.model?.modelName ?? '');
    _selectedProvider = widget.model?.provider ?? AiProvider.chutes;
  }

  @override
  void dispose() {
    _modelNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit Model' : 'Add Model'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<AiProvider>(
              initialValue: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'Provider',
              ),
              items: AiProvider.values.map((provider) {
                return DropdownMenuItem(
                  value: provider,
                  child: Row(
                    children: [
                      Image.asset(
                        provider.iconPath,
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(provider.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedProvider = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _modelNameController,
              decoration: const InputDecoration(
                labelText: 'Model Name',
                hintText: 'e.g., deepseek-ai/DeepSeek-V3',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a model name';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      if (isEditing) {
        final model = widget.model!.copyWith(
          modelName: _modelNameController.text.trim(),
          provider: _selectedProvider,
        );
        await ref.read(aiModelProvider.notifier).updateModel(model);
      } else {
        final model = AiModel.create(
          modelName: _modelNameController.text.trim(),
          provider: _selectedProvider,
        );
        await ref.read(aiModelProvider.notifier).addModel(model);
      }
      navigator.pop();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
