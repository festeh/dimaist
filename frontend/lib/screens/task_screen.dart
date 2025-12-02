import 'package:dimaist/widgets/completed_task_widget.dart';
import 'package:dimaist/services/logging_service.dart';
import 'package:dimaist/widgets/custom_view_widget.dart';
import 'package:dimaist/config/design_tokens.dart';
import 'package:dimaist/widgets/task_form_dialog.dart';
import 'package:dimaist/widgets/schedule_view.dart';
import 'package:dimaist/widgets/view_options_menu.dart';
import 'package:dimaist/utils/value_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:dimaist/widgets/error_dialog.dart';
import 'package:dimaist/widgets/task_widget.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../models/app_bar_config.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../enums/sort_mode.dart';
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
  bool _showCompletedTasks = false;

  void _updateAppBarConfig(String title, SortMode sortMode) {
    widget.onAppBarConfigChanged?.call(
      AppBarConfig(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(width: 4),
            ViewOptionsMenu(
              sortMode: sortMode,
              isScheduleView: _isScheduleView,
              showScheduleToggle: widget.customView?.type == BuiltInViewType.today,
              onSortToggle: () async {
                final taskNotifier = ref.read(taskProvider.notifier);
                final newSortMode = sortMode == SortMode.order
                    ? SortMode.dueDate
                    : SortMode.order;
                await taskNotifier.setSortMode(newSortMode);
              },
              onScheduleToggle: widget.customView?.type == BuiltInViewType.today
                  ? () {
                      LoggingService.logger.fine(
                        'Toggle button pressed! Current state: $_isScheduleView',
                      );
                      setState(() {
                        _isScheduleView = !_isScheduleView;
                      });
                      LoggingService.logger.fine('New state: $_isScheduleView');
                    }
                  : null,
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
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
        onDelete: _deleteTask,
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
        // Update app bar config with the task data title and sort mode
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateAppBarConfig(taskData.title, taskData.sortMode);
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

    // Get projects for lookup (only needed in custom views)
    final projects = widget.customView != null
        ? (ref.read(projectProvider).valueOrNull ?? <Project>[])
        : <Project>[];

    Project? findProject(Task task) {
      if (widget.customView == null) return null;
      return projects.where((p) => p.id == task.projectId).firstOrNull;
    }

    return Column(
      children: [
        // Inline toolbar
        Padding(
          padding: const EdgeInsets.only(
            left: Spacing.xs,
            right: Spacing.xs,
            top: Spacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: PhosphorIcon(PhosphorIcons.plus(), size: Sizes.iconSm),
                onPressed: _showAddTaskDialog,
                tooltip: 'Add Task',
              ),
              ViewOptionsMenu(
                sortMode: taskData.sortMode,
                isScheduleView: _isScheduleView,
                showScheduleToggle:
                    widget.customView?.type == BuiltInViewType.today,
                onSortToggle: () async {
                  final taskNotifier = ref.read(taskProvider.notifier);
                  final newSortMode = taskData.sortMode == SortMode.order
                      ? SortMode.dueDate
                      : SortMode.order;
                  await taskNotifier.setSortMode(newSortMode);
                },
                onScheduleToggle:
                    widget.customView?.type == BuiltInViewType.today
                        ? () {
                            setState(() {
                              _isScheduleView = !_isScheduleView;
                            });
                          }
                        : null,
              ),
            ],
          ),
        ),
        Expanded(
          child:
              (widget.customView?.type == BuiltInViewType.today &&
                  _isScheduleView)
              ? (() {
                  return ScheduleView(
                    tasks: taskData.tasks,
                    onToggleComplete: _toggleComplete,
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
                      PhosphorIcon(PhosphorIcons.checkCircle(), size: 64),
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
                  final canReorder = taskData.sortMode == SortMode.order;

                  if (canReorder) {
                    return ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                      itemCount:
                          nonCompletedTasks.length +
                          (completedTasks.isNotEmpty
                              ? (_showCompletedTasks ? completedTasks.length + 1 : 1)
                              : 0),
                      itemBuilder: (context, index) {
                        if (index < nonCompletedTasks.length) {
                          final task = nonCompletedTasks[index];
                          return TaskWidget(
                            key: Key(task.id.toString()),
                            task: task,
                            onToggleComplete: _toggleComplete,
                            onEdit: _showEditTaskDialog,
                            showDragHandle: true,
                            dragIndex: index,
                            project: findProject(task),
                          );
                        } else if (index == nonCompletedTasks.length &&
                            completedTasks.isNotEmpty) {
                          return InkWell(
                            key: const Key('completed_tasks_header'),
                            onTap: () => setState(() => _showCompletedTasks = !_showCompletedTasks),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: Spacing.lg,
                                horizontal: Spacing.md,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      thickness: 1,
                                      color: Theme.of(context).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                                    child: Row(
                                      children: [
                                        PhosphorIcon(
                                          _showCompletedTasks
                                              ? PhosphorIcons.caretDown()
                                              : PhosphorIcons.caretRight(),
                                          size: Sizes.iconSm,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: Spacing.xs),
                                        Text(
                                          'Completed (${completedTasks.length})',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      thickness: 1,
                                      color: Theme.of(context).colorScheme.outlineVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                            onEdit: _showEditTaskDialog,
                            project: findProject(task),
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
                  } else {
                    // Non-reorderable ListView for date sorting
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                      itemCount:
                          nonCompletedTasks.length +
                          (completedTasks.isNotEmpty
                              ? (_showCompletedTasks ? completedTasks.length + 1 : 1)
                              : 0),
                      itemBuilder: (context, index) {
                        if (index < nonCompletedTasks.length) {
                          final task = nonCompletedTasks[index];
                          return TaskWidget(
                            key: Key(task.id.toString()),
                            task: task,
                            onToggleComplete: _toggleComplete,
                            onEdit: _showEditTaskDialog,
                            showDragHandle: false,
                            dragIndex: null,
                            project: findProject(task),
                          );
                        } else if (index == nonCompletedTasks.length &&
                            completedTasks.isNotEmpty) {
                          return InkWell(
                            onTap: () => setState(() => _showCompletedTasks = !_showCompletedTasks),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: Spacing.lg,
                                horizontal: Spacing.md,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      thickness: 1,
                                      color: Theme.of(context).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                                    child: Row(
                                      children: [
                                        PhosphorIcon(
                                          _showCompletedTasks
                                              ? PhosphorIcons.caretDown()
                                              : PhosphorIcons.caretRight(),
                                          size: Sizes.iconSm,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: Spacing.xs),
                                        Text(
                                          'Completed (${completedTasks.length})',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      thickness: 1,
                                      color: Theme.of(context).colorScheme.outlineVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                            onEdit: _showEditTaskDialog,
                            project: findProject(task),
                          );
                        }
                      },
                    );
                  }
                })(),
        ),
        ChatInputWidget(
          onSendMessage: _handleAiMessage,
          isProcessing: _isAiProcessing,
        ),
      ],
    );
  }
}
