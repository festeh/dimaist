import 'package:flutter/material.dart';
import '../config/design_tokens.dart';
import 'tasks_tab.dart';

class LeftBar extends StatefulWidget {
  final String? selectedView;
  final Function(String) onCustomViewSelected;
  final VoidCallback onAddProject;
  final VoidCallback onOpenLabels;
  final VoidCallback onOpenSettings;
  final Widget projectList;

  const LeftBar({
    super.key,
    required this.selectedView,
    required this.onCustomViewSelected,
    required this.onAddProject,
    required this.onOpenLabels,
    required this.onOpenSettings,
    required this.projectList,
  });

  @override
  State<LeftBar> createState() => _LeftBarState();
}

class _LeftBarState extends State<LeftBar> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Sizes.sidebarWidth,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            right: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        child: TasksTab(
          selectedView: widget.selectedView,
          onCustomViewSelected: widget.onCustomViewSelected,
          onAddProject: widget.onAddProject,
          onOpenLabels: widget.onOpenLabels,
          onOpenSettings: widget.onOpenSettings,
          projectList: widget.projectList,
        ),
      ),
    );
  }
}
