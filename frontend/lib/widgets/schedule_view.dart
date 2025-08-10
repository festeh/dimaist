import 'package:flutter/material.dart';
import '../models/task.dart';

class ScheduleView extends StatelessWidget {
  final List<Task> tasks;
  final Function(Task) onToggleComplete;
  final Function(int) onDelete;
  final Function(Task) onEdit;
  final Function(Task, DateTime) onScheduleTask;
  final Function(Task) onUnscheduleTask;

  const ScheduleView({
    super.key,
    required this.tasks,
    required this.onToggleComplete,
    required this.onDelete,
    required this.onEdit,
    required this.onScheduleTask,
    required this.onUnscheduleTask,
  });

  @override
  Widget build(BuildContext context) {
    // Create time slots from 6:00 to 23:30 (30-minute intervals)
    final timeSlots = <DateTime>[];
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, 6, 0);
    
    for (int i = 0; i <= 35; i++) { // 6:00 to 23:30 = 35 slots of 30 minutes
      timeSlots.add(startTime.add(Duration(minutes: i * 30)));
    }

    // Separate tasks with and without time slots
    final scheduledTasks = tasks.where((task) => 
      task.startDatetime != null && task.endDatetime != null
    ).toList();
    final unscheduledTasks = tasks.where((task) => 
      task.startDatetime == null || task.endDatetime == null
    ).toList();

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
                  itemCount: timeSlots.length,
                  itemBuilder: (context, index) {
                    final timeSlot = timeSlots[index];
                    final tasksInSlot = scheduledTasks.where((task) {
                      if (task.startDatetime == null || task.endDatetime == null) {
                        return false;
                      }
                      final taskStart = task.startDatetime!;
                      final taskEnd = task.endDatetime!;
                      final slotEnd = timeSlot.add(const Duration(minutes: 30));
                      
                      // Check if task overlaps with this time slot
                      return (taskStart.isBefore(slotEnd) && taskEnd.isAfter(timeSlot));
                    }).toList();

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
                      child: Row(
                        children: [
                          // Time label
                          Container(
                            width: 80,
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${timeSlot.hour.toString().padLeft(2, '0')}:${timeSlot.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          // Tasks in this slot
                          Expanded(
                            child: DragTarget<Task>(
                              onAcceptWithDetails: (details) {
                                onScheduleTask(details.data, timeSlot);
                              },
                              builder: (context, candidateData, rejectedData) {
                                return Container(
                                  decoration: candidateData.isNotEmpty
                                      ? BoxDecoration(
                                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(4),
                                        )
                                      : null,
                                  child: tasksInSlot.isNotEmpty
                                      ? Wrap(
                                          children: tasksInSlot.map((task) => 
                                            _buildScheduledTaskCard(context, task)
                                          ).toList(),
                                        )
                                      : Container(
                                          height: 40,
                                          alignment: Alignment.center,
                                          child: candidateData.isNotEmpty
                                              ? Text(
                                                  'Drop task here',
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.primary,
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
                      onUnscheduleTask(details.data);
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        decoration: candidateData.isNotEmpty
                            ? BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildScheduledTaskCard(BuildContext context, Task task) {
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
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.drag_handle,
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                task.description,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            GestureDetector(
              onTap: () => onToggleComplete(task),
              child: Icon(
                task.completedAt != null 
                    ? Icons.check_circle 
                    : Icons.circle_outlined,
                size: 16,
                color: task.completedAt != null 
                    ? Theme.of(context).colorScheme.onSurfaceVariant 
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.drag_handle,
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
          ],
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.drag_handle,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.description,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
              onTap: () => onToggleComplete(task),
              child: Icon(
                task.completedAt != null 
                    ? Icons.check_circle 
                    : Icons.circle_outlined,
                size: 18,
                color: task.completedAt != null 
                    ? Theme.of(context).colorScheme.onSurfaceVariant 
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.drag_handle,
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
}
