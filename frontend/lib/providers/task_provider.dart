import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../utils/value_wrapper.dart';
import '../widgets/custom_view_widget.dart';
import '../repositories/providers.dart';
import '../repositories/interfaces/task_repository_interface.dart';
import 'view_provider.dart';

// Sentinel object for unchanged values in copyWith
const Object _unchanged = Object();

class TaskState {
  final List<Task> tasks;
  final bool isLoading;
  final String? error;
  final ViewSelection? currentView;

  const TaskState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.currentView,
  });

  TaskState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    Object? error = _unchanged,
    ViewSelection? currentView,
  }) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error == _unchanged ? this.error : error as String?,
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

class TaskNotifier extends StateNotifier<TaskState> {
  final ITaskRepository _repository;

  TaskNotifier(this._repository) : super(const TaskState());

  Future<void> loadTasks({Project? project, CustomView? customView}) async {
    // Create the appropriate view selection
    ViewSelection? viewSelection;
    if (project != null) {
      viewSelection = ProjectViewSelection(project);
    } else if (customView != null) {
      viewSelection = CustomViewSelection(customView);
    }

    state = state.copyWith(
      currentView: viewSelection,
      isLoading: true,
      error: null,
    );

    try {
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

      state = state.copyWith(tasks: tasks, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Error loading tasks: $e',
        isLoading: false,
      );
    }
  }

  Future<void> createTask(Task task) async {
    try {
      state = state.copyWith(error: null);
      await _repository.createTask(task);
      await _reloadCurrentTasks();
    } catch (e) {
      state = state.copyWith(error: 'Error creating task: $e');
      rethrow;
    }
  }

  Future<void> updateTask(int id, Task task) async {
    try {
      state = state.copyWith(error: null);
      await _repository.updateTask(id, task);
      await _reloadCurrentTasks();
    } catch (e) {
      state = state.copyWith(error: 'Error updating task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      state = state.copyWith(error: null);
      await _repository.deleteTask(id);
      await _reloadCurrentTasks();
    } catch (e) {
      state = state.copyWith(error: 'Error deleting task: $e');
      rethrow;
    }
  }

  Future<void> toggleComplete(Task task) async {
    try {
      state = state.copyWith(error: null);
      if (task.completedAt != null) {
        final updatedTask = task.copyWith(
          completedAt: const ValueWrapper(null),
        );
        await _repository.updateTask(task.id!, updatedTask);
      } else {
        await _repository.completeTask(task.id!);
      }
      await _reloadCurrentTasks();
    } catch (e) {
      state = state.copyWith(error: 'Error toggling task completion: $e');
      rethrow;
    }
  }

  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    final currentView = state.currentView;
    if (currentView is! ProjectViewSelection) return;
    final nonCompleted = state.nonCompletedTasks;

    if (oldIndex >= nonCompleted.length || newIndex > nonCompleted.length) {
      return;
    }

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    try {
      state = state.copyWith(error: null);

      // Update UI immediately
      final task = nonCompleted.removeAt(oldIndex);
      nonCompleted.insert(newIndex, task);
      final updatedTasks = [...nonCompleted, ...state.completedTasks];
      state = state.copyWith(tasks: updatedTasks);

      // Update order on server
      final allProjectTaskIds = nonCompleted.map((t) => t.id!).toList();
      await _repository.reorderTasks(currentView.project.id!, allProjectTaskIds);
    } catch (e) {
      state = state.copyWith(error: 'Error reordering tasks: $e');
      // If reorder fails, reload from the source of truth
      await _reloadCurrentTasks();
      rethrow;
    }
  }

  Future<void> syncData() async {
    try {
      state = state.copyWith(error: null);
      await _repository.syncTasks();
      await _reloadCurrentTasks();
    } catch (e) {
      state = state.copyWith(error: 'Error syncing tasks: $e');
      rethrow;
    }
  }

  Future<Project?> getDefaultProjectForToday() async {
    return _repository.getDefaultProjectForToday();
  }

  Future<void> _reloadCurrentTasks() async {
    final currentView = state.currentView;
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

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return TaskNotifier(repository);
});
