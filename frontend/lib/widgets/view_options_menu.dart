import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../enums/sort_mode.dart';
import '../config/design_tokens.dart';

class ViewOptionsMenu extends StatelessWidget {
  final SortMode sortMode;
  final bool isScheduleView;
  final bool showScheduleToggle;
  final VoidCallback onSortToggle;
  final VoidCallback? onScheduleToggle;
  final bool showCompletedTasks;
  final VoidCallback? onShowCompletedToggle;

  const ViewOptionsMenu({
    super.key,
    required this.sortMode,
    required this.isScheduleView,
    required this.showScheduleToggle,
    required this.onSortToggle,
    this.onScheduleToggle,
    this.showCompletedTasks = false,
    this.onShowCompletedToggle,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: PhosphorIcon(PhosphorIcons.dotsThreeVertical(), size: Sizes.iconSm),
      tooltip: 'View Options',
      onSelected: (value) {
        switch (value) {
          case 'sort':
            onSortToggle();
            break;
          case 'schedule':
            onScheduleToggle?.call();
            break;
          case 'completed':
            onShowCompletedToggle?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'sort',
          child: Row(
            children: [
              PhosphorIcon(
                sortMode == SortMode.order ? PhosphorIcons.sortAscending() : PhosphorIcons.calendarBlank(),
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
                PhosphorIcon(
                  isScheduleView ? PhosphorIcons.list() : PhosphorIcons.calendar(),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(isScheduleView ? 'List View' : 'Schedule View'),
              ],
            ),
          ),
        if (onShowCompletedToggle != null)
          PopupMenuItem<String>(
            value: 'completed',
            child: Row(
              children: [
                PhosphorIcon(
                  showCompletedTasks ? PhosphorIcons.eyeSlash() : PhosphorIcons.eye(),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(showCompletedTasks ? 'Hide Completed' : 'Show Completed'),
              ],
            ),
          ),
      ],
    );
  }
}