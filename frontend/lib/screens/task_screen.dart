import 'package:dimaist/widgets/completed_task_widget.dart';
import 'package:dimaist/services/logging_service.dart';
import 'package:dimaist/widgets/custom_view_widget.dart';
import 'package:dimaist/widgets/task_form_dialog.dart';
import 'package:dimaist/widgets/schedule_view.dart';
import 'package:dimaist/utils/value_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dimaist/widgets/error_dialog.dart';
import 'package:dimaist/widgets/task_widget.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../models/app_bar_config.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import 'package:dimaist/widgets/chat_input_widget.dart';
import 'ai_chat_screen.dart';

class TaskScreen extends ConsumerStatefulWidget {
  final Project? project;
  final CustomView? customView;
  final Function(AppBarConfig?)? onAppBarConfigChanged;

  const TaskScreen({
    super.key, 
    this.project, 
    this.customView,
    this.onAppBarConfigChanged,
  }) : assert(project != null || customView != null);

  @override
  TaskScreenState createState() => TaskScreenState();
}

class TaskScreenState extends ConsumerState<TaskScreen> {
  bool _isScheduleView = false;
  bool _isAiProcessing = false;

  void _updateAppBarConfig(String title) {
    widget.onAppBarConfigChanged?.call(
      AppBarConfig(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (widget.customView?.type == BuiltInViewType.today) ...[
              const SizedBox(width: 8),
              IconButton(
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isScheduleView ? Icons.list : Icons.calendar_view_day,
                ),
                onPressed: () {
                  LoggingService.logger.fine(
                    'Toggle button pressed! Current state: $_isScheduleView',
                  );
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
        actions: const [],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taskNotifier = ref.read(taskProvider.notifier);
      taskNotifier.loadTasks(
        project: widget.project,
        customView: widget.customView,
      );
    });
  }

  @override
  void didUpdateWidget(TaskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project != widget.project ||
        oldWidget.customView != widget.customView) {
      final taskNotifier = ref.read(taskProvider.notifier);
      taskNotifier.loadTasks(
        project: widget.project,
        customView: widget.customView,
      );
    }
  }

  void showAddTaskDialog() {
    _showAddTaskDialog();
  }

  Future<void> _sync() async {
    final taskNotifier = ref.read(taskProvider.notifier);
    try {
      await taskNotifier.syncData();
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
    final taskNotifier = ref.read(taskProvider.notifier);
    try {
      await taskNotifier.deleteTask(id);
    } catch (e) {
      _showErrorDialog('Error deleting task: $e');
    }
  }

  Future<void> _toggleComplete(Task task) async {
    final taskNotifier = ref.read(taskProvider.notifier);
    try {
      await taskNotifier.toggleComplete(task);
    } catch (e) {
      _showErrorDialog('Error toggling task completion: $e');
    }
  }

  void _showAddTaskDialog() async {
    final taskNotifier = ref.read(taskProvider.notifier);
    final projectAsyncValue = ref.read(projectProvider);

    final projects = projectAsyncValue.valueOrNull ?? <Project>[];
    Project? selectedProject = widget.project;
    DateTime? defaultDueDate;

    if (widget.customView?.type == BuiltInViewType.today) {
      try {
        selectedProject = await taskNotifier.getDefaultProjectForToday();
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
        projects: projects,
        selectedProject: selectedProject,
        defaultDueDate: defaultDueDate,
        onSave: (task) async {
          await taskNotifier.createTask(task);
        },
        title: 'Add New Task',
        submitButtonText: 'Add',
      ),
    );
  }

  void _showEditTaskDialog(Task task) {
    final taskNotifier = ref.read(taskProvider.notifier);
    final projectAsyncValue = ref.read(projectProvider);

    final projects = projectAsyncValue.valueOrNull ?? <Project>[];

    showDialog(
      context: context,
      builder: (context) => TaskFormDialog(
        task: task,
        projects: projects,
        onSave: (updatedTask) async {
          await taskNotifier.updateTask(task.id!, updatedTask);
        },
        title: 'Edit Task',
        submitButtonText: 'Save',
      ),
    );
  }

  Future<void> _scheduleTask(Task task, DateTime timeSlot) async {
    final taskNotifier = ref.read(taskProvider.notifier);

    try {
      final updatedTask = task.copyWith(
        startDatetime: ValueWrapper(timeSlot),
        endDatetime: ValueWrapper(
          timeSlot.add(const Duration(minutes: 30)),
        ), // Default 30-minute duration
      );

      await taskNotifier.updateTask(task.id!, updatedTask);
    } catch (e) {
      LoggingService.logger.severe('Error scheduling task: $e');
      _showErrorDialog('Error scheduling task: $e');
    }
  }

  Future<void> _unscheduleTask(Task task) async {
    final taskNotifier = ref.read(taskProvider.notifier);

    try {
      final updatedTask = task.copyWith(
        startDatetime: const ValueWrapper(null),
        endDatetime: const ValueWrapper(null),
      );

      await taskNotifier.updateTask(task.id!, updatedTask);
    } catch (e) {
      LoggingService.logger.severe('Error unscheduling task: $e');
      _showErrorDialog('Error unscheduling task: $e');
    }
  }

  Future<void> _updateTask(Task task) async {
    final taskNotifier = ref.read(taskProvider.notifier);

    try {
      await taskNotifier.updateTask(task.id!, task);
    } catch (e) {
      LoggingService.logger.severe('Error updating task: $e');
      _showErrorDialog('Error updating task: $e');
    }
  }

  Future<void> _handleAiMessage(String message) async {
    if (_isAiProcessing) return;

    setState(() {
      _isAiProcessing = true;
    });

    try {
      // For now, just navigate to AI chat screen with the message
      // Later we can integrate inline AI processing
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AiChatScreen(initialMessage: message),
        ),
      );
    } catch (e) {
      LoggingService.logger.severe('Error handling AI message: $e');
      _showErrorDialog('Error processing AI message: $e');
    } finally {
      setState(() {
        _isAiProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsyncValue = ref.watch(taskProvider);
    final taskNotifier = ref.read(taskProvider.notifier);

    return taskAsyncValue.when(
      data: (taskData) {
        // Update app bar config with the task data title
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateAppBarConfig(taskData.title);
        });
        return _buildTaskContent(context, taskData, taskNotifier);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading tasks: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => taskNotifier.loadTasks(
                project: widget.project,
                customView: widget.customView,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskContent(
    BuildContext context,
    TaskViewData taskData,
    TaskNotifier taskNotifier,
  ) {
    final nonCompletedTasks = taskData.nonCompletedTasks;
    final completedTasks = widget.customView?.type == BuiltInViewType.today
        ? <Task>[]
        : taskData.completedTasks;

    return Column(
      children: [
        Expanded(
          child:
              (widget.customView?.type == BuiltInViewType.today &&
                  _isScheduleView)
              ? (() {
                  return ScheduleView(
                    tasks: taskData.tasks,
                    onToggleComplete: _toggleComplete,
                    onDelete: _deleteTask,
                    onEdit: _showEditTaskDialog,
                    onScheduleTask: _scheduleTask,
                    onUnscheduleTask: _unscheduleTask,
                    onUpdateTask: _updateTask,
                  );
                })()
              : taskData.tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        widget.customView?.type == BuiltInViewType.today
                            ? 'No tasks for today'
                            : 'No tasks yet!',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      if (widget.customView?.type != BuiltInViewType.today)
                        Text(
                          'Click the "+" button to add your first task.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                    ],
                  ),
                )
              : (() {
                  return ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.all(8.0),
                    itemCount:
                        nonCompletedTasks.length +
                        (completedTasks.isNotEmpty
                            ? completedTasks.length + 1
                            : 0),
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
                            completedTasks[index -
                                nonCompletedTasks.length -
                                1];
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
                        await taskNotifier.reorderTasks(oldIndex, newIndex);
                      } catch (e) {
                        _showErrorDialog('Error reordering tasks: $e');
                      }
                    },
                  );
                })(),
        ),
        ChatInputWidget(
          onSendMessage: _handleAiMessage,
          onAddPressed: _showAddTaskDialog,
          isProcessing: _isAiProcessing,
        ),
      ],
    );
  }
}
