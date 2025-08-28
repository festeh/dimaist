import 'package:flutter/material.dart';
import '../models/project.dart';
import '../utils/color_utils.dart';

class ProjectList extends StatelessWidget {
  final List<Project> projects;
  final int selectedIndex;
  final Function(int) onProjectSelected;
  final Function(int, int) onReorder;
  final Function(Project) onEdit;
  final Function(int) onDelete;

  const ProjectList({
    super.key,
    required this.projects,
    required this.selectedIndex,
    required this.onProjectSelected,
    required this.onReorder,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorder: onReorder,
      children: List.generate(projects.length, (index) {
        final project = projects[index];
        return Container(
          key: Key(project.id.toString()),
          decoration: BoxDecoration(
            color: selectedIndex == index
                ? Theme.of(context).highlightColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () => onProjectSelected(index),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Opacity(
                      opacity: 0.6,
                      child: Icon(
                        Icons.drag_handle,
                        size: 20,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: getColor(project.color),
                    radius: 12,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      project.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: selectedIndex == index
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit(project);
                      } else if (value == 'delete') {
                        onDelete(project.id!);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
