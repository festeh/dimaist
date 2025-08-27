import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../utils/value_wrapper.dart';
import '../widgets/custom_view_widget.dart';
import '../repositories/providers.dart';
import '../repositories/interfaces/task_repository_interface.dart';
import 'view_provider.dart';

class TaskViewData {
  final List<Task> tasks;
  final ViewSelection? currentView;

  const TaskViewData({this.tasks = const [], this.currentView});

  TaskViewData copyWith({List<Task>? tasks, ViewSelection? currentView}) {
    return TaskViewData(
      tasks: tasks ?? this.tasks,
      currentView: currentView ?? this.currentView,
    );
  }

  List<Task> get nonCompletedTasks =>
      tasks.where((task) => task.completedAt == null).toList();

  List<Task> get completedTasks {
    final completed = tasks.where((task) => task.completedAt != null).toList();
    completed.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    return completed;
  }

  String get title {
    return switch (currentView) {
      ProjectViewSelection(project: final project) =>
        'Tasks for ${project.name}',
      CustomViewSelection(customView: final customView) => customView.name,
      null => 'Tasks',
    };
  }
}

class TaskNotifier extends AsyncNotifier<TaskViewData> {
  ITaskRepository get _repository => ref.read(taskRepositoryProvider);

  @override
  Future<TaskViewData> build() async {
    return const TaskViewData();
  }

  Future<void> loadTasks({Project? project, CustomView? customView}) async {
    // Create the appropriate view selection
    ViewSelection? viewSelection;
    if (project != null) {
      viewSelection = ProjectViewSelection(project);
    } else if (customView != null) {
      viewSelection = CustomViewSelection(customView);
    }

    state = await AsyncValue.guard(() async {
      final tasks = await switch (viewSelection) {
        ProjectViewSelection(project: final proj) when proj.id != null =>
          _repository.getTasksByProject(proj.id!),
        ProjectViewSelection() => Future.value(
          <Task>[],
        ), // Handle case where project has no id
        CustomViewSelection(customView: final view) => switch (view.type) {
          BuiltInViewType.today => _repository.getTodayTasks(),
          BuiltInViewType.upcoming => _repository.getUpcomingTasks(),
          BuiltInViewType.next => _repository.getTasksByLabel('next'),
        },
        null => Future.value(<Task>[]),
      };

      return TaskViewData(tasks: tasks, currentView: viewSelection);
    });
  }

  Future<void> createTask(Task task) async {
    await _repository.createTask(task);
    await _reloadCurrentTasks();
  }

  Future<void> updateTask(int id, Task task) async {
    await _repository.updateTask(id, task);
    await _reloadCurrentTasks();
  }

  Future<void> deleteTask(int id) async {
    await _repository.deleteTask(id);
    await _reloadCurrentTasks();
  }

  Future<void> toggleComplete(Task task) async {
    if (task.completedAt != null) {
      final updatedTask = task.copyWith(completedAt: const ValueWrapper(null));
      await _repository.updateTask(task.id!, updatedTask);
    } else {
      await _repository.completeTask(task.id!);
    }
    await _reloadCurrentTasks();
  }

  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    state = await AsyncValue.guard(() async {
      final currentData = state.valueOrNull ?? const TaskViewData();
      final currentView = currentData.currentView;
      if (currentView is! ProjectViewSelection) return currentData;

      final nonCompleted = currentData.nonCompletedTasks;
      if (oldIndex >= nonCompleted.length || newIndex > nonCompleted.length) {
        return currentData;
      }

      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      // Update UI immediately
      final task = nonCompleted.removeAt(oldIndex);
      nonCompleted.insert(newIndex, task);
      final updatedTasks = [...nonCompleted, ...currentData.completedTasks];

      // Update order on server
      final allProjectTaskIds = nonCompleted.map((t) => t.id!).toList();
      await _repository.reorderTasks(
        currentView.project.id!,
        allProjectTaskIds,
      );

      return currentData.copyWith(tasks: updatedTasks);
    });
  }

  Future<void> syncData() async {
    await _repository.syncTasks();
    await _reloadCurrentTasks();
  }

  Future<Project?> getDefaultProjectForToday() async {
    return _repository.getDefaultProjectForToday();
  }

  Future<void> _reloadCurrentTasks() async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final currentView = currentData.currentView;
    switch (currentView) {
      case ProjectViewSelection(project: final project):
        await loadTasks(project: project);
      case CustomViewSelection(customView: final customView):
        await loadTasks(customView: customView);
      case null:
        // No current view, nothing to reload
        break;
    }
  }
}

final taskProvider = AsyncNotifierProvider<TaskNotifier, TaskViewData>(
  () => TaskNotifier(),
);
