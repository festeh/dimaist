import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/project_provider.dart';
import '../utils/color_utils.dart';
import 'project_form_widget.dart';

class AddProjectDialog extends ConsumerStatefulWidget {
  final VoidCallback onProjectAdded;

  const AddProjectDialog({super.key, required this.onProjectAdded});

  @override
  ConsumerState<AddProjectDialog> createState() => AddProjectDialogState();
}

class AddProjectDialogState extends ConsumerState<AddProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  ProjectColor _selectedColor = ProjectColor.grey;
  String? _selectedIcon;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Project'),
      content: ProjectFormWidget(
        formKey: _formKey,
        nameController: _nameController,
        selectedColor: _selectedColor,
        selectedIcon: _selectedIcon,
        onColorChanged: (value) => setState(() => _selectedColor = value),
        onIconChanged: (value) => setState(() => _selectedIcon = value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(projectProvider.notifier).addProject(
                      _nameController.text,
                      _selectedColor.displayName,
                      _selectedIcon,
                    );
                navigator.pop();
                widget.onProjectAdded();
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Error creating project: $e')),
                );
              }
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
