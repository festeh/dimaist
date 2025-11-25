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
  late TextEditingController _displayNameController;
  late TextEditingController _apiIdController;

  bool get isEditing => widget.model != null;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.model?.displayName ?? '');
    _apiIdController = TextEditingController(text: widget.model?.apiId ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _apiIdController.dispose();
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
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'e.g., DeepSeek V3.1',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a display name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiIdController,
              decoration: const InputDecoration(
                labelText: 'API Identifier',
                hintText: 'e.g., chutes/deepseek-ai/DeepSeek-V3.1',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an API identifier';
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
          displayName: _displayNameController.text.trim(),
          apiId: _apiIdController.text.trim(),
        );
        await ref.read(aiModelProvider.notifier).updateModel(model);
      } else {
        final model = AiModel.create(
          displayName: _displayNameController.text.trim(),
          apiId: _apiIdController.text.trim(),
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
