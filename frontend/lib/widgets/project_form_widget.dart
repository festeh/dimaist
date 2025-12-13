import 'package:flutter/material.dart';
import '../config/design_tokens.dart';
import '../models/project.dart';
import '../utils/color_utils.dart';
import 'icon_picker_dialog.dart';
import 'project_icon_widget.dart';

/// Shared form widget for project name, color, and icon selection
class ProjectFormWidget extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final ProjectColor selectedColor;
  final String? selectedIcon;
  final ValueChanged<ProjectColor> onColorChanged;
  final ValueChanged<String?> onIconChanged;

  const ProjectFormWidget({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.selectedColor,
    required this.selectedIcon,
    required this.onColorChanged,
    required this.onIconChanged,
  });

  Future<void> _pickIcon(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => IconPickerDialog(
        iconColor: selectedColor.color,
        selectedIcon: selectedIcon,
      ),
    );

    if (result != null) {
      onIconChanged(result.isEmpty ? null : result);
    }
  }

  Widget _buildIconPreview() {
    // Create a temporary project for preview
    final previewProject = Project(
      id: 0,
      name: '',
      color: selectedColor.name,
      icon: selectedIcon,
      order: 0,
    );
    return ProjectIconWidget.medium(project: previewProject);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: nameController,
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
                child: DropdownButtonFormField<ProjectColor>(
                  initialValue: selectedColor,
                  decoration: const InputDecoration(labelText: 'Color'),
                  items: ProjectColor.values.map((color) {
                    return DropdownMenuItem<ProjectColor>(
                      value: color,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color.color,
                            radius: 10,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            color.displayName,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) onColorChanged(value);
                  },
                ),
              ),
              const SizedBox(width: Spacing.md),
              InkWell(
                onTap: () => _pickIcon(context),
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
    );
  }
}
