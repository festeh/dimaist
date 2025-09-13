import 'package:flutter/material.dart';
import '../enums/sort_mode.dart';

class ViewOptionsMenu extends StatelessWidget {
  final SortMode sortMode;
  final bool isScheduleView;
  final bool showScheduleToggle;
  final VoidCallback onSortToggle;
  final VoidCallback? onScheduleToggle;

  const ViewOptionsMenu({
    super.key,
    required this.sortMode,
    required this.isScheduleView,
    required this.showScheduleToggle,
    required this.onSortToggle,
    this.onScheduleToggle,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'View Options',
      onSelected: (value) {
        switch (value) {
          case 'sort':
            onSortToggle();
            break;
          case 'schedule':
            onScheduleToggle?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'sort',
          child: Row(
            children: [
              Icon(
                sortMode == SortMode.order ? Icons.reorder : Icons.sort,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                sortMode == SortMode.order
                    ? 'Sort by Due Date'
                    : 'Sort Manually',
              ),
            ],
          ),
        ),
        if (showScheduleToggle)
          PopupMenuItem<String>(
            value: 'schedule',
            child: Row(
              children: [
                Icon(
                  isScheduleView ? Icons.list : Icons.calendar_view_day,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(isScheduleView ? 'List View' : 'Schedule View'),
              ],
            ),
          ),
      ],
    );
  }
}