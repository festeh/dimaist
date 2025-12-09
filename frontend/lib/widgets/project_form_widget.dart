import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../utils/color_utils.dart';
import '../utils/icon_utils.dart';
import 'icon_picker_dialog.dart';

/// Shared form widget for project name, color, and icon selection
class ProjectFormWidget extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final String? selectedColor;
  final String? selectedIcon;
  final ValueChanged<String?> onColorChanged;
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
        iconColor: getColor(selectedColor ?? 'Grey'),
        selectedIcon: selectedIcon,
      ),
    );

    if (result != null) {
      onIconChanged(result.isEmpty ? null : result);
    }
  }

  Widget _buildIconPreview() {
    final color = getColor(selectedColor ?? 'Grey');
    if (selectedIcon != null && selectedIcon!.isNotEmpty) {
      return PhosphorIcon(
        getIcon(selectedIcon),
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
                child: DropdownButtonFormField<String>(
                  initialValue: selectedColor,
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
                  onChanged: onColorChanged,
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
