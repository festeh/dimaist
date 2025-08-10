import 'package:flutter/material.dart';
import 'package:dimaist/services/app_database.dart';
import '../models/project.dart';
import '../services/api_service.dart';
import '../utils/color_utils.dart';

class AddProjectDialog extends StatefulWidget {
  final VoidCallback onProjectAdded;

  const AddProjectDialog({super.key, required this.onProjectAdded});

  @override
  AddProjectDialogState createState() => AddProjectDialogState();
}

class AddProjectDialogState extends State<AddProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedColor;
  final AppDatabase _db = AppDatabase();

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
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
                final projects = await _db.allProjects;
                final newOrder = (projects.isNotEmpty
                        ? projects
                            .map((p) => p.order)
                            .reduce((a, b) => a > b ? a : b)
                        : 0) +
                    1;
                final project = Project(
                  name: _nameController.text,
                  color: _selectedColor!,
                  order: newOrder,
                );
                await ApiService.createProject(project);
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
