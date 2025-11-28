import 'package:dimaist/widgets/custom_view_widget.dart';
import 'package:dimaist/widgets/search_bar_widget.dart';
import 'package:dimaist/widgets/toolbar_menu.dart';
import 'package:dimaist/config/design_tokens.dart';
import 'package:flutter/material.dart';

class TasksTab extends StatelessWidget {
  final String? selectedView;
  final Function(String) onCustomViewSelected;
  final VoidCallback onAddProject;
  final VoidCallback onArrangeProjects;
  final VoidCallback onOpenLabels;
  final VoidCallback onOpenSettings;
  final Widget projectList;

  const TasksTab({
    super.key,
    required this.selectedView,
    required this.onCustomViewSelected,
    required this.onAddProject,
    required this.onArrangeProjects,
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
          // Top toolbar with search bar and menu
          Padding(
            padding: const EdgeInsets.only(
              left: Spacing.sm,
              top: Spacing.sm,
            ),
            child: Row(
              children: [
                const Expanded(child: SearchBarWidget()),
                ToolbarMenu(
                  onAddProject: onAddProject,
                  onArrangeProjects: onArrangeProjects,
                  onOpenLabels: onOpenLabels,
                  onOpenSettings: onOpenSettings,
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
