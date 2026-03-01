import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../utils/value_wrapper.dart';
import '../widgets/custom_view_widget.dart';
import '../services/api_service.dart';
import '../services/app_database.dart';
import '../services/sort_preferences.dart';
import '../enums/sort_mode.dart';
import 'service_providers.dart';
import 'view_provider.dart';

class TaskViewData {
  final List<Task> tasks;
  final ViewSelection? currentView;
  final SortMode sortMode;

  const TaskViewData({
    this.tasks = const [],
    this.currentView,
    this.sortMode = SortMode.order,
  });

  TaskViewData copyWith({
    List<Task>? tasks,
    ViewSelection? currentView,
    SortMode? sortMode,
  }) {
    return TaskViewData(
      tasks: tasks ?? this.tasks,
      currentView: currentView ?? this.currentView,
      sortMode: sortMode ?? this.sortMode,
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
      ProjectViewSelection(project: final project) => project.name,
      CustomViewSelection(customView: final customView) => customView.name,
      null => 'Tasks',
    };
  }
}

class TaskNotifier extends AsyncNotifier<TaskViewData> {
  ApiService get _api => ref.read(apiServiceProvider);
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  Future<TaskViewData> build() async {
    return const TaskViewData();
  }

  Future<List<Task>> _fetchTasks(ViewSelection? view, SortMode sortMode) {
    return switch (view) {
      ProjectViewSelection(project: final proj) when proj.id != null =>
        _db.getTasksByProject(proj.id!, sortMode: sortMode),
      ProjectViewSelection() => Future.value(<Task>[]),
      CustomViewSelection(customView: final view) => switch (view.type) {
        BuiltInViewType.today => _db.getTodayTasks(sortMode: sortMode),
        BuiltInViewType.upcoming => _db.getUpcomingTasks(sortMode: sortMode),
        BuiltInViewType.next => _db.getTasksByLabel('next', sortMode: sortMode),
        BuiltInViewType.all => _db.getAllUncompletedTasks(sortMode: sortMode),
      },
      null => Future.value(<Task>[]),
    };
  }

  Future<void> loadTasks({Project? project, CustomView? customView}) async {
    ViewSelection? viewSelection;
    if (project != null) {
      viewSelection = ProjectViewSelection(project);
    } else if (customView != null) {
      viewSelection = CustomViewSelection(customView);
    }

    state = await AsyncValue.guard(() async {
      final sortMode = await _getSortModeForView(viewSelection);
      final tasks = await _fetchTasks(viewSelection, sortMode);
      return TaskViewData(
        tasks: tasks,
        currentView: viewSelection,
        sortMode: sortMode,
      );
    });
  }

  /// Creates a task. Returns a warning if calendar sync failed.
  Future<String?> createTask(Task task) async {
    final (createdTask, warning) = await _api.createTask(task);
    await _db.insertTask(createdTask);
    await _reloadCurrentTasks();
    return warning;
  }

  /// Updates a task. Returns a warning if calendar sync failed.
  Future<String?> updateTask(int id, Task task) async {
    final warning = await _api.updateTask(id, task);
    await _db.updateTask(task);
    await _reloadCurrentTasks();
    return warning;
  }

  Future<void> deleteTask(int id) async {
    await _api.deleteTask(id);
    await _db.deleteTask(id);
    await _reloadCurrentTasks();
  }

  Future<void> toggleComplete(Task task) async {
    if (task.completedAt != null) {
      final updatedTask = task.copyWith(completedAt: const ValueWrapper(null));
      await _api.updateTask(task.id!, updatedTask);
      await _db.updateTask(updatedTask);
    } else {
      await _api.completeTask(task.id!);
      final updatedTask = await _api.getTask(task.id!);
      await _db.updateTask(updatedTask);
    }
    await _reloadCurrentTasks();
  }

  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    final currentData = state.value ?? const TaskViewData();
    final currentView = currentData.currentView;
    if (currentView is! ProjectViewSelection) return;

    if (currentData.sortMode != SortMode.order) return;

    final nonCompleted = currentData.nonCompletedTasks;
    if (oldIndex >= nonCompleted.length || newIndex > nonCompleted.length) {
      return;
    }

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final task = nonCompleted.removeAt(oldIndex);
    nonCompleted.insert(newIndex, task);
    final updatedTasks = [...nonCompleted, ...currentData.completedTasks];

    state = AsyncValue.data(currentData.copyWith(tasks: updatedTasks));

    try {
      final allProjectTaskIds = nonCompleted.map((t) => t.id!).toList();
      await _api.reorderTasks(currentView.project.id!, allProjectTaskIds);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> syncData() async {
    await _syncFromServer();
    await _reloadCurrentTasks();
  }

  Future<void> fullResync() async {
    await _db.clearDatabase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sync_token');
    await _syncFromServer();
    await _reloadCurrentTasks();
  }

  Future<void> _syncFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final syncToken = prefs.getString('sync_token');
    final syncResponse = await _api.fetchSyncData(syncToken);
    await _db.applySyncResponse(syncResponse);
    await prefs.setString('sync_token', syncResponse.syncToken);
  }

  Future<Project?> getDefaultProjectForToday() async {
    final projects = await _db.allProjects;
    final defaultProject = projects.where((p) => p.name == 'Inbox');

    if (defaultProject.isNotEmpty) {
      return defaultProject.first;
    }

    if (projects.isNotEmpty) {
      return projects.first;
    }

    throw Exception('No projects found');
  }

  Future<void> setSortMode(SortMode newSortMode) async {
    final currentData = state.value;
    if (currentData == null) return;

    final currentView = currentData.currentView;

    await _saveSortModeForView(currentView, newSortMode);

    final tasks = await _fetchTasks(currentView, newSortMode);

    state = AsyncValue.data(
      currentData.copyWith(tasks: tasks, sortMode: newSortMode),
    );
  }

  Future<SortMode> _getSortModeForView(ViewSelection? viewSelection) async {
    return switch (viewSelection) {
      ProjectViewSelection(project: final project) when project.id != null =>
        await SortPreferences.getSortModeForProject(project.id!),
      CustomViewSelection(customView: final view) =>
        await SortPreferences.getSortModeForCustomView(view.type),
      _ => SortMode.order,
    };
  }

  Future<void> _saveSortModeForView(
    ViewSelection? viewSelection,
    SortMode sortMode,
  ) async {
    switch (viewSelection) {
      case ProjectViewSelection(project: final project) when project.id != null:
        await SortPreferences.setSortModeForProject(project.id!, sortMode);
      case ProjectViewSelection():
        break;
      case CustomViewSelection(customView: final view):
        await SortPreferences.setSortModeForCustomView(view.type, sortMode);
      case null:
        break;
    }
  }

  Future<void> _reloadCurrentTasks() async {
    final currentData = state.value;
    if (currentData == null) return;

    final currentView = currentData.currentView;
    switch (currentView) {
      case ProjectViewSelection(project: final project):
        await loadTasks(project: project);
      case CustomViewSelection(customView: final customView):
        await loadTasks(customView: customView);
      case null:
        break;
    }
  }
}

final taskProvider = AsyncNotifierProvider<TaskNotifier, TaskViewData>(
  () => TaskNotifier(),
);
