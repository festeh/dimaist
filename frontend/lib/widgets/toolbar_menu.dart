import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
      icon: PhosphorIcon(PhosphorIcons.dotsThreeVertical(), size: Sizes.iconSm),
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
        PopupMenuItem(
          value: 'add_project',
          child: Row(
            children: [
              PhosphorIcon(PhosphorIcons.plusCircle(), size: Sizes.iconSm),
              const SizedBox(width: Spacing.md),
              const Text('Add Project'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'arrange_projects',
          child: Row(
            children: [
              PhosphorIcon(PhosphorIcons.arrowsDownUp(), size: Sizes.iconSm),
              const SizedBox(width: Spacing.md),
              const Text('Arrange Projects'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'labels',
          child: Row(
            children: [
              PhosphorIcon(PhosphorIcons.tag(), size: Sizes.iconSm),
              const SizedBox(width: Spacing.md),
              const Text('Labels'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              PhosphorIcon(PhosphorIcons.gear(), size: Sizes.iconSm),
              const SizedBox(width: Spacing.md),
              const Text('Settings'),
            ],
          ),
        ),
      ],
    );
  }
}
