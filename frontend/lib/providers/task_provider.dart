import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../services/app_database.dart';
import '../services/api_service.dart';
import '../utils/value_wrapper.dart';
import '../widgets/custom_view_widget.dart';
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

  List<Task> get nonCompletedTasks => tasks.where((task) => task.completedAt == null).toList();
  
  List<Task> get completedTasks {
    final completed = tasks.where((task) => task.completedAt != null).toList();
    completed.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    return completed;
  }

  String get title {
    return switch (currentView) {
      ProjectViewSelection(project: final project) => 'Tasks for ${project.name}',
      CustomViewSelection(customView: final customView) => customView.name,
      null => 'Tasks',
    };
  }
}

class TaskNotifier extends StateNotifier<TaskState> {
  final AppDatabase _db = AppDatabase();

  TaskNotifier() : super(const TaskState());

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
          _db.getTasksByProject(proj.id!),
        ProjectViewSelection() => Future.value(<Task>[]), // Handle case where project has no id
        CustomViewSelection(customView: final view) => switch (view.type) {
          BuiltInViewType.today => _db.getTodayTasks(),
          BuiltInViewType.upcoming => _db.getUpcomingTasks(),
          BuiltInViewType.next => _db.getTasksByLabel('next'),
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
      await ApiService.createTask(task);
      await _reloadCurrentTasks();
    } catch (e) {
      state = state.copyWith(error: 'Error creating task: $e');
      rethrow;
    }
  }

  Future<void> updateTask(int id, Task task) async {
    try {
      state = state.copyWith(error: null);
      await ApiService.updateTask(id, task);
      await _reloadCurrentTasks();
    } catch (e) {
      state = state.copyWith(error: 'Error updating task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      state = state.copyWith(error: null);
      await ApiService.deleteTask(id);
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
        await ApiService.updateTask(task.id!, updatedTask);
      } else {
        await ApiService.completeTask(task.id!);
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

      // Update order in database
      for (int i = 0; i < nonCompleted.length; i++) {
        final taskToUpdate = nonCompleted[i];
        if (taskToUpdate.order != i) {
          await _db.updateTask(taskToUpdate.copyWith(order: i));
        }
      }

      // Update order on server
      final allProjectTaskIds = nonCompleted.map((t) => t.id!).toList();
      await ApiService.reorderTasks(currentView.project.id!, allProjectTaskIds);
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
      await ApiService.syncData();
      await _reloadCurrentTasks();
    } catch (e) {
      state = state.copyWith(error: 'Error syncing tasks: $e');
      rethrow;
    }
  }

  Future<Project?> getDefaultProjectForToday() async {
    final projects = await _db.allProjects;
    return projects.firstWhere(
      (p) => p.name == 'Inbox',
      orElse: () => projects.isNotEmpty ? projects.first : throw Exception('No projects found'),
    );
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
  return TaskNotifier();
});