import 'package:dimaist/widgets/custom_view_widget.dart';
import 'package:flutter/material.dart';

class TasksTab extends StatelessWidget {
  final String? selectedView;
  final Function(String) onCustomViewSelected;
  final VoidCallback onAddProject;
  final VoidCallback onOpenSettings;
  final Widget projectList;

  const TasksTab({
    super.key,
    required this.selectedView,
    required this.onCustomViewSelected,
    required this.onAddProject,
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onAddProject,
                  tooltip: 'Add Project',
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: onOpenSettings,
                  tooltip: 'Settings',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
