import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../providers/project_provider.dart';
import '../utils/color_utils.dart';
import '../utils/icon_utils.dart';
import 'icon_picker_dialog.dart';

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
  String? _selectedIcon;

  @override
  void initState() {
    super.initState();
    _selectedColor = colorMap.keys.first;
  }

  Future<void> _pickIcon() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => IconPickerDialog(
        iconColor: getColor(_selectedColor ?? 'Grey'),
        selectedIcon: _selectedIcon,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedIcon = result.isEmpty ? null : result;
      });
    }
  }

  Widget _buildIconPreview() {
    final color = getColor(_selectedColor ?? 'Grey');
    if (_selectedIcon != null && _selectedIcon!.isNotEmpty) {
      return PhosphorIcon(
        getIcon(_selectedIcon),
        color: color,
        size: Sizes.iconMd,
      );
    }
    return Container(
      width: Sizes.iconMd,
      height: Sizes.iconMd,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Project'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Project Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a project name';
                }
                return null;
              },
            ),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedColor,
                    decoration: const InputDecoration(labelText: 'Color'),
                    items: colorMap.keys.map((String colorName) {
                      return DropdownMenuItem<String>(
                        value: colorName,
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: colorMap[colorName],
                              radius: 10,
                            ),
                            const SizedBox(width: 10),
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
                ),
                const SizedBox(width: Spacing.md),
                InkWell(
                  onTap: _pickIcon,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: Container(
                    padding: const EdgeInsets.all(Spacing.sm),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildIconPreview(),
                        const SizedBox(width: Spacing.xs),
                        Icon(
                          Icons.arrow_drop_down,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(projectProvider.notifier).addProject(
                      _nameController.text,
                      _selectedColor!,
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
