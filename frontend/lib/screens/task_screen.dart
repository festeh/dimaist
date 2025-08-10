import 'package:dimaist/widgets/completed_task_widget.dart';
import 'package:dimaist/services/logging_service.dart';
import 'package:dimaist/widgets/custom_view_widget.dart';
import 'package:dimaist/widgets/task_form_dialog.dart';
import 'package:dimaist/widgets/schedule_view.dart';
import 'package:dimaist/utils/value_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dimaist/widgets/error_dialog.dart';
import 'package:dimaist/widgets/task_widget.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import 'package:dimaist/widgets/long_press_fab.dart';

class TaskScreen extends StatefulWidget {
  final Project? project;
  final CustomView? customView;

  const TaskScreen({super.key, this.project, this.customView})
    : assert(project != null || customView != null);

  @override
  TaskScreenState createState() => TaskScreenState();
}

class TaskScreenState extends State<TaskScreen> {
  bool _isScheduleView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      taskProvider.loadTasks(project: widget.project, customView: widget.customView);
    });
  }


  void showAddTaskDialog() {
    _showAddTaskDialog();
  }

  Future<void> _sync() async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    try {
      await taskProvider.syncData();
    } catch (e) {
      _showErrorDialog('Error syncing tasks: $e');
    }
  }

  void _showErrorDialog(String error) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(error: error, onSync: _sync),
    );
  }

  Future<void> _deleteTask(int id) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    try {
      await taskProvider.deleteTask(id);
    } catch (e) {
      _showErrorDialog('Error deleting task: $e');
    }
  }

  Future<void> _toggleComplete(Task task) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    try {
      await taskProvider.toggleComplete(task);
    } catch (e) {
      _showErrorDialog('Error toggling task completion: $e');
    }
  }

  void _showAddTaskDialog() async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    
    Project? selectedProject = widget.project;
    DateTime? defaultDueDate;

    if (widget.customView?.name == 'Today') {
      try {
        selectedProject = await taskProvider.getDefaultProjectForToday();
        defaultDueDate = DateTime.now();
      } catch (e) {
        _showErrorDialog('Error loading default project: $e');
        return;
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => TaskFormDialog(
        projects: projectProvider.projects,
        selectedProject: selectedProject,
        defaultDueDate: defaultDueDate,
        onSave: (task) async {
          await taskProvider.createTask(task);
        },
        title: 'Add New Task',
        submitButtonText: 'Add',
      ),
    );
  }

  void _showEditTaskDialog(Task task) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => TaskFormDialog(
        task: task,
        projects: projectProvider.projects,
        onSave: (updatedTask) async {
          await taskProvider.updateTask(task.id!, updatedTask);
        },
        title: 'Edit Task',
        submitButtonText: 'Save',
      ),
    );
  }

  Future<void> _scheduleTask(Task task, DateTime timeSlot) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    
    try {
      final updatedTask = task.copyWith(
        startDatetime: ValueWrapper(timeSlot),
        endDatetime: ValueWrapper(timeSlot.add(const Duration(minutes: 30))), // Default 30-minute duration
      );
      
      await taskProvider.updateTask(task.id!, updatedTask);
    } catch (e) {
      LoggingService.logger.severe('Error scheduling task: $e');
      _showErrorDialog('Error scheduling task: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final nonCompletedTasks = taskProvider.nonCompletedTasks;
        final completedTasks = widget.customView?.name == 'Today'
            ? <Task>[]
            : taskProvider.completedTasks;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(taskProvider.title, style: Theme.of(context).textTheme.headlineSmall),
                if (widget.customView?.name == 'Today') ...[
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(_isScheduleView ? Icons.list : Icons.calendar_view_day),
                    onPressed: () {
                      LoggingService.logger.fine('Toggle button pressed! Current state: $_isScheduleView');
                      setState(() {
                        _isScheduleView = !_isScheduleView;
                      });
                      LoggingService.logger.fine('New state: $_isScheduleView');
                    },
                    tooltip: _isScheduleView ? 'List View' : 'Schedule View',
                  ),
                ],
              ],
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: taskProvider.isLoading
              ? const Center(child: SizedBox.shrink())
              : (widget.customView?.name == 'Today' && _isScheduleView)
          ? (() {
              LoggingService.logger.fine('Showing ScheduleView - customView: ${widget.customView?.name}, isScheduleView: $_isScheduleView');
              return ScheduleView(
                tasks: taskProvider.tasks,
                onToggleComplete: _toggleComplete,
                onDelete: _deleteTask,
                onEdit: _showEditTaskDialog,
                onScheduleTask: _scheduleTask,
              );
            })()
          : taskProvider.tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    widget.customView?.name == 'Today'
                        ? 'No tasks for today'
                        : 'No tasks yet!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  if (widget.customView?.name != 'Today')
                    Text(
                      'Click the "+" button to add your first task.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                ],
              ),
            )
          : (() {
              LoggingService.logger.fine('Showing ListView - customView: ${widget.customView?.name}, isScheduleView: $_isScheduleView');
              return ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.all(8.0),
              itemCount:
                  nonCompletedTasks.length +
                  (completedTasks.isNotEmpty ? completedTasks.length + 1 : 0),
              itemBuilder: (context, index) {
                if (index < nonCompletedTasks.length) {
                  final task = nonCompletedTasks[index];
                  return ReorderableDragStartListener(
                    key: Key(task.id.toString()),
                    index: index,
                    child: TaskWidget(
                      task: task,
                      onToggleComplete: _toggleComplete,
                      onDelete: _deleteTask,
                      onEdit: _showEditTaskDialog,
                    ),
                  );
                } else if (index == nonCompletedTasks.length &&
                    completedTasks.isNotEmpty) {
                  return Column(
                    key: const Key('completed_tasks_header'),
                    children: const [
                      Divider(
                        height: 32,
                        thickness: 2,
                        indent: 16,
                        endIndent: 16,
                      ),
                      Text('Completed tasks'),
                    ],
                  );
                } else {
                  final task =
                      completedTasks[index - nonCompletedTasks.length - 1];
                  return CompletedTaskWidget(
                    key: Key(task.id.toString()),
                    task: task,
                    onToggleComplete: _toggleComplete,
                    onDelete: _deleteTask,
                    onEdit: _showEditTaskDialog,
                  );
                }
              },
              onReorder: (oldIndex, newIndex) async {
                try {
                  await taskProvider.reorderTasks(oldIndex, newIndex);
                } catch (e) {
                  _showErrorDialog('Error reordering tasks: $e');
                }
              },
            );
          })(),
          floatingActionButton: LongPressFab(
            onPressed: _showAddTaskDialog,
            onMenuItemSelected: (value) {
              // ignore: avoid_print
              LoggingService.logger.fine('Reorder callback: $value');
            },
          ),
        );
      },
    );
  }
}
