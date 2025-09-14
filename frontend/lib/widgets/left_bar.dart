import 'package:dimaist/widgets/tasks_tab.dart';
import 'package:flutter/material.dart';

class LeftBar extends StatefulWidget {
  final String? selectedView;
  final Function(String) onCustomViewSelected;
  final VoidCallback onAddProject;
  final VoidCallback onOpenSettings;
  final Widget projectList;

  const LeftBar({
    super.key,
    required this.selectedView,
    required this.onCustomViewSelected,
    required this.onAddProject,
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
      width: 248,
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
          onOpenSettings: widget.onOpenSettings,
          projectList: widget.projectList,
        ),
      ),
    );
  }
}
