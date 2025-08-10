import 'package:flutter/material.dart';
import '../models/task.dart';

class ScheduleView extends StatelessWidget {
  final List<Task> tasks;
  final Function(Task) onToggleComplete;
  final Function(int) onDelete;
  final Function(Task) onEdit;

  const ScheduleView({
    super.key,
    required this.tasks,
    required this.onToggleComplete,
    required this.onDelete,
    required this.onEdit,
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
                  style: Theme.of(context).textTheme.titleLarge,
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
                            color: Colors.grey.shade300,
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
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          // Tasks in this slot
                          Expanded(
                            child: tasksInSlot.isNotEmpty
                                ? Wrap(
                                    children: tasksInSlot.map((task) => 
                                      _buildScheduledTaskCard(context, task)
                                    ).toList(),
                                  )
                                : const SizedBox(),
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
        if (unscheduledTasks.isNotEmpty)
          Container(
            width: 200,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Colors.grey.shade300,
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
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: unscheduledTasks.length,
                    itemBuilder: (context, index) {
                      final task = unscheduledTasks[index];
                      return _buildUnscheduledTaskCard(context, task);
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
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: task.completedAt != null 
            ? Colors.grey.shade200 
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: task.completedAt != null 
              ? Colors.grey.shade400 
              : Colors.blue.shade200,
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
                  ? Colors.grey.shade600 
                  : Colors.blue.shade600,
            ),
          ),
          const SizedBox(width: 4),
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
                    ? Colors.grey.shade600 
                    : Colors.black87,
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
                color: Colors.grey.shade700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnscheduledTaskCard(BuildContext context, Task task) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: task.completedAt != null 
            ? Colors.grey.shade100 
            : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.grey.shade300,
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
                  ? Colors.grey.shade600 
                  : Colors.blue.shade600,
            ),
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
                    ? Colors.grey.shade600 
                    : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}