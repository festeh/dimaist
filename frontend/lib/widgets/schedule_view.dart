import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/task.dart';
import '../utils/value_wrapper.dart';

class ScheduleView extends StatefulWidget {
  final List<Task> tasks;
  final Function(Task) onToggleComplete;
  final Function(Task) onEdit;
  final Function(Task, DateTime) onScheduleTask;
  final Function(Task) onUnscheduleTask;
  final Function(Task)? onUpdateTask;

  const ScheduleView({
    super.key,
    required this.tasks,
    required this.onToggleComplete,
    required this.onEdit,
    required this.onScheduleTask,
    required this.onUnscheduleTask,
    this.onUpdateTask,
  });

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Auto-scroll to current time after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, 6, 0);

    if (now.isBefore(startTime)) {
      // If current time is before 6:00, scroll to top
      _scrollController.jumpTo(0);
      return;
    }

    final endTime = DateTime(now.year, now.month, now.day, 23, 30);
    if (now.isAfter(endTime)) {
      // If current time is after 23:30, scroll to bottom
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      return;
    }

    // Calculate which time slot the current time falls into
    final timeDifference = now.difference(startTime);
    final slotIndex = (timeDifference.inMinutes / 30).floor();

    // Scroll so current time is near the top (but not at the very top)
    const itemHeight = 60.0; // Height of each time slot
    final scrollOffset =
        (slotIndex * itemHeight) -
        (itemHeight * 2); // Show 2 slots above current time

    _scrollController.jumpTo(
      scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  void _adjustTaskDuration(Task task, int minutesToAdd) {
    if (task.startDatetime == null || task.endDatetime == null) return;

    final newEndTime = task.endDatetime!.add(Duration(minutes: minutesToAdd));

    // Create updated task with new end time, keeping the same start time
    final updatedTask = task.copyWith(endDatetime: ValueWrapper(newEndTime));

    // Use onUpdateTask if available, otherwise fall back to onEdit
    if (widget.onUpdateTask != null) {
      widget.onUpdateTask!(updatedTask);
    } else {
      widget.onEdit(updatedTask);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create time slots from 6:00 to 23:30 (30-minute intervals)
    final timeSlots = <DateTime>[];
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, 6, 0);

    for (int i = 0; i <= 35; i++) {
      // 6:00 to 23:30 = 35 slots of 30 minutes
      timeSlots.add(startTime.add(Duration(minutes: i * 30)));
    }

    // Separate tasks with and without time slots
    final scheduledTasks = widget.tasks
        .where((task) => task.startDatetime != null && task.endDatetime != null)
        .toList();
    final unscheduledTasks = widget.tasks
        .where((task) => task.startDatetime == null || task.endDatetime == null)
        .toList();

    return Row(
      children: [
        // Main schedule grid
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Schedule',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              // Time grid
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: timeSlots.length,
                  itemBuilder: (context, index) {
                    final timeSlot = timeSlots[index];
                    final tasksInSlot = scheduledTasks.where((task) {
                      if (task.startDatetime == null ||
                          task.endDatetime == null) {
                        return false;
                      }
                      final taskStart = task.startDatetime!;
                      final taskEnd = task.endDatetime!;
                      final slotEnd = timeSlot.add(const Duration(minutes: 30));

                      // Check if task overlaps with this time slot
                      return (taskStart.isBefore(slotEnd) &&
                          taskEnd.isAfter(timeSlot));
                    }).toList();

                    // Check if current time falls within this slot
                    final slotEnd = timeSlot.add(const Duration(minutes: 30));
                    final isCurrentTimeInSlot =
                        now.isAfter(timeSlot) && now.isBefore(slotEnd);

                    return Container(
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Row(
                            children: [
                              // Time label
                              Container(
                                width: 80,
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  '${timeSlot.hour.toString().padLeft(2, '0')}:${timeSlot.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              // Tasks in this slot
                              Expanded(
                                child: DragTarget<Task>(
                                  onAcceptWithDetails: (details) {
                                    widget.onScheduleTask(
                                      details.data,
                                      timeSlot,
                                    );
                                  },
                                  builder: (context, candidateData, rejectedData) {
                                    return Container(
                                      decoration: candidateData.isNotEmpty
                                          ? BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer
                                                  .withValues(alpha: 0.3),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            )
                                          : null,
                                      child: tasksInSlot.isNotEmpty
                                          ? Column(
                                              children: tasksInSlot
                                                  .map(
                                                    (task) => Expanded(
                                                      child:
                                                          _buildScheduledTaskCard(
                                                            context,
                                                            task,
                                                            timeSlot,
                                                          ),
                                                    ),
                                                  )
                                                  .toList(),
                                            )
                                          : Container(
                                              height: 40,
                                              alignment: Alignment.center,
                                              child: candidateData.isNotEmpty
                                                  ? Text(
                                                      'Task starts here',
                                                      style: TextStyle(
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                        fontSize: 12,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          // Current time indicator
                          if (isCurrentTimeInSlot)
                            _buildCurrentTimeIndicator(now, timeSlot),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Unscheduled tasks sidebar
        Container(
          width: 200,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Unscheduled',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: DragTarget<Task>(
                  onAcceptWithDetails: (details) {
                    // Unschedule the task by setting start/end times to null
                    widget.onUnscheduleTask(details.data);
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Container(
                      decoration: candidateData.isNotEmpty
                          ? BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            )
                          : null,
                      child: unscheduledTasks.isNotEmpty
                          ? ListView.builder(
                              itemCount: unscheduledTasks.length,
                              itemBuilder: (context, index) {
                                final task = unscheduledTasks[index];
                                return _buildUnscheduledTaskCard(context, task);
                              },
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  candidateData.isNotEmpty
                                      ? 'Drop here to unschedule'
                                      : 'No unscheduled tasks',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: candidateData.isNotEmpty
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduledTaskCard(
    BuildContext context,
    Task task,
    DateTime currentTimeSlot,
  ) {
    final taskDuration = task.startDatetime != null && task.endDatetime != null
        ? task.endDatetime!.difference(task.startDatetime!).inMinutes
        : 0;
    final canShrink = taskDuration > 30;

    // Check if this is the starting cell for the task (aligned to 30-minute slots)
    final isStartingCell =
        task.startDatetime != null &&
        task.startDatetime!.hour == currentTimeSlot.hour &&
        task.startDatetime!.minute == currentTimeSlot.minute;

    return Draggable<Task>(
      data: task,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1,
            ),
          ),
          child: Text(
            task.description,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      childWhenDragging: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        height: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIcons.dotsSixVertical(),
              size: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                task.description,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Container(
          margin: const EdgeInsets.all(0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          height: double.infinity,
          decoration: BoxDecoration(
            color: task.completedAt != null
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: task.completedAt != null
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context).colorScheme.primary,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Minus button (left side) - only show in starting cell
              if (isStartingCell) ...[
                _HoverButton(
                  onTap: canShrink
                      ? () => _adjustTaskDuration(task, -30)
                      : null,
                  enabled: canShrink,
                  child: PhosphorIcon(
                    PhosphorIcons.minus(),
                    size: 14,
                    color: canShrink
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(width: 2),
              ] else ...[
                // Invisible placeholder to maintain width
                const SizedBox(
                  width: 18, // 14 (icon) + 4 (padding)
                  height: 18,
                ),
                const SizedBox(width: 2),
              ],
              GestureDetector(
                onTap: () => widget.onToggleComplete(task),
                child: PhosphorIcon(
                  task.completedAt != null
                      ? PhosphorIcons.checkCircle()
                      : PhosphorIcons.circle(),
                  size: 16,
                  color: task.completedAt != null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              PhosphorIcon(
                PhosphorIcons.dotsSixVertical(),
                size: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  task.description,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: task.completedAt != null
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.completedAt != null
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (task.startDatetime != null && task.endDatetime != null)
                Text(
                  ' ${task.startDatetime!.hour.toString().padLeft(2, '0')}:${task.startDatetime!.minute.toString().padLeft(2, '0')}-${task.endDatetime!.hour.toString().padLeft(2, '0')}:${task.endDatetime!.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: task.completedAt != null
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              // Plus button (right side) - only show in starting cell
              if (isStartingCell) ...[
                const SizedBox(width: 2),
                _HoverButton(
                  onTap: () => _adjustTaskDuration(task, 30),
                  enabled: true,
                  child: PhosphorIcon(
                    PhosphorIcons.plus(),
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ] else ...[
                // Invisible placeholder to maintain width
                const SizedBox(width: 2),
                const SizedBox(
                  width: 18, // 14 (icon) + 4 (padding)
                  height: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnscheduledTaskCard(BuildContext context, Task task) {
    return Draggable<Task>(
      data: task,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1,
            ),
          ),
          child: Text(
            task.description,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      childWhenDragging: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.dotsSixVertical(),
              size: 18,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.description,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: task.completedAt != null
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => widget.onToggleComplete(task),
              child: PhosphorIcon(
                task.completedAt != null
                    ? PhosphorIcons.checkCircle()
                    : PhosphorIcons.circle(),
                size: 18,
                color: task.completedAt != null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            PhosphorIcon(
              PhosphorIcons.dotsSixVertical(),
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.description,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: task.completedAt != null
                      ? TextDecoration.lineThrough
                      : null,
                  color: task.completedAt != null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(DateTime now, DateTime timeSlot) {
    // Calculate the exact position within the 30-minute slot
    final minutesFromSlotStart = now.difference(timeSlot).inMinutes;
    final slotHeight = 60.0;
    final linePosition = (minutesFromSlotStart / 30.0) * slotHeight;

    return Positioned(
      top: linePosition,
      left: 0,
      right: 0,
      child: Container(height: 2, color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _HoverButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool enabled;
  final Widget child;

  const _HoverButton({
    required this.onTap,
    required this.enabled,
    required this.child,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _isHovered && widget.enabled
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
