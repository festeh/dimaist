import 'package:dimaist/widgets/custom_view_widget.dart';
import 'package:dimaist/config/design_tokens.dart';
import 'package:flutter/material.dart';

class TasksTab extends StatelessWidget {
  final String? selectedView;
  final Function(String) onCustomViewSelected;
  final VoidCallback onAddProject;
  final VoidCallback onOpenLabels;
  final VoidCallback onOpenSettings;
  final Widget projectList;

  const TasksTab({
    super.key,
    required this.selectedView,
    required this.onCustomViewSelected,
    required this.onAddProject,
    required this.onOpenLabels,
    required this.onOpenSettings,
    required this.projectList,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Top toolbar with actions
          Padding(
            padding: const EdgeInsets.only(
              left: Spacing.xs,
              right: Spacing.xs,
              top: Spacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onAddProject,
                  tooltip: 'Add Project',
                  iconSize: Sizes.iconSm,
                ),
                IconButton(
                  icon: const Icon(Icons.label_outline),
                  onPressed: onOpenLabels,
                  tooltip: 'Labels',
                  iconSize: Sizes.iconSm,
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: onOpenSettings,
                  tooltip: 'Settings',
                  iconSize: Sizes.iconSm,
                ),
              ],
            ),
          ),
          CustomViewWidget(
            selectedView: selectedView,
            onSelected: onCustomViewSelected,
          ),
          Divider(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            height: 1,
            thickness: 1,
          ),
          Expanded(child: projectList),
        ],
      ),
    );
  }
}
