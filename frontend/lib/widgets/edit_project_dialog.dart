import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import '../utils/color_utils.dart';
import 'project_form_widget.dart';

class EditProjectDialog extends ConsumerStatefulWidget {
  final Project project;
  final VoidCallback onProjectUpdated;

  const EditProjectDialog({
    super.key,
    required this.project,
    required this.onProjectUpdated,
  });

  @override
  ConsumerState<EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends ConsumerState<EditProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late ProjectColor _selectedColor;
  String? _selectedIcon;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
    _selectedColor = ProjectColor.fromString(widget.project.color);
    _selectedIcon = widget.project.icon;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Project'),
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
                final updatedProject = Project(
                  id: widget.project.id,
                  name: _nameController.text,
                  color: _selectedColor.displayName,
                  icon: _selectedIcon,
                  order: widget.project.order,
                );
                await ref
                    .read(projectProvider.notifier)
                    .updateProject(updatedProject);
                navigator.pop();
                widget.onProjectUpdated();
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Error updating project: $e')),
                );
              }
            }
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}
