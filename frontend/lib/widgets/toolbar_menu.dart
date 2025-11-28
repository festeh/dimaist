import 'package:flutter/material.dart';
import '../config/design_tokens.dart';

class ToolbarMenu extends StatelessWidget {
  final VoidCallback onAddProject;
  final VoidCallback onArrangeProjects;
  final VoidCallback onOpenLabels;
  final VoidCallback onOpenSettings;

  const ToolbarMenu({
    super.key,
    required this.onAddProject,
    required this.onArrangeProjects,
    required this.onOpenLabels,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: Sizes.iconSm),
      tooltip: 'Menu',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 40),
      onSelected: (value) {
        switch (value) {
          case 'add_project':
            onAddProject();
            break;
          case 'arrange_projects':
            onArrangeProjects();
            break;
          case 'labels':
            onOpenLabels();
            break;
          case 'settings':
            onOpenSettings();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'add_project',
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, size: Sizes.iconSm),
              SizedBox(width: Spacing.md),
              Text('Add Project'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'arrange_projects',
          child: Row(
            children: [
              Icon(Icons.swap_vert, size: Sizes.iconSm),
              SizedBox(width: Spacing.md),
              Text('Arrange Projects'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'labels',
          child: Row(
            children: [
              Icon(Icons.label_outline, size: Sizes.iconSm),
              SizedBox(width: Spacing.md),
              Text('Labels'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings, size: Sizes.iconSm),
              SizedBox(width: Spacing.md),
              Text('Settings'),
            ],
          ),
        ),
      ],
    );
  }
}
