import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/project_provider.dart';
import '../utils/color_utils.dart';

class AddProjectDialog extends ConsumerStatefulWidget {
  final VoidCallback onProjectAdded;

  const AddProjectDialog({super.key, required this.onProjectAdded});

  @override
  ConsumerState<AddProjectDialog> createState() => AddProjectDialogState();
}

class AddProjectDialogState extends ConsumerState<AddProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = colorMap.keys.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add New Project'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Project Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a project name';
                }
                return null;
              },
            ),
            DropdownButtonFormField<String>(
              value: _selectedColor,
              decoration: InputDecoration(labelText: 'Color'),
              items: colorMap.keys.map((String colorName) {
                return DropdownMenuItem<String>(
                  value: colorName,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: colorMap[colorName],
                        radius: 10,
                      ),
                      SizedBox(width: 10),
                      Text(
                        colorName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedColor = newValue;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a color';
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
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(projectProvider.notifier).addProject(
                  _nameController.text,
                  _selectedColor!,
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
          child: Text('Add'),
        ),
      ],
    );
  }
}
