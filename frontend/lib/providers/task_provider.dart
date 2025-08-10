import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../services/app_database.dart';
import '../services/api_service.dart';
import '../utils/value_wrapper.dart';
import '../widgets/custom_view_widget.dart';

class TaskProvider extends ChangeNotifier {
  final AppDatabase _db = AppDatabase();
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;
  Project? _currentProject;
  CustomView? _currentCustomView;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Project? get currentProject => _currentProject;
  CustomView? get currentCustomView => _currentCustomView;

  List<Task> get nonCompletedTasks => _tasks.where((task) => task.completedAt == null).toList();
  List<Task> get completedTasks {
    final completed = _tasks.where((task) => task.completedAt != null).toList();
    completed.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    return completed;
  }

  String get title {
    if (_currentProject != null) {
      return 'Tasks for ${_currentProject!.name}';
    }
    if (_currentCustomView != null) {
      return _currentCustomView!.name;
    }
    return 'Tasks';
  }

  Future<void> loadTasks({Project? project, CustomView? customView}) async {
    _currentProject = project;
    _currentCustomView = customView;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      List<Task> tasks;
      if (project != null && project.id != null) {
        tasks = await _db.getTasksByProject(project.id!);
      } else if (customView?.name == 'Today') {
        tasks = await _db.getTodayTasks();
      } else if (customView?.name == 'Upcoming') {
        tasks = await _db.getUpcomingTasks();
      } else if (customView?.name == 'Next') {
        tasks = await _db.getTasksByLabel('next');
      } else {
        tasks = [];
      }
      
      _tasks = tasks;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error loading tasks: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createTask(Task task) async {
    try {
      _error = null;
      await ApiService.createTask(task);
      await _reloadCurrentTasks();
    } catch (e) {
      _error = 'Error creating task: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateTask(int id, Task task) async {
    try {
      _error = null;
      await ApiService.updateTask(id, task);
      await _reloadCurrentTasks();
    } catch (e) {
      _error = 'Error updating task: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      _error = null;
      await ApiService.deleteTask(id);
      await _reloadCurrentTasks();
    } catch (e) {
      _error = 'Error deleting task: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleComplete(Task task) async {
    try {
      _error = null;
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
      _error = 'Error toggling task completion: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (_currentProject == null) return;
    final nonCompleted = nonCompletedTasks;
    
    if (oldIndex >= nonCompleted.length || newIndex > nonCompleted.length) {
      return;
    }

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    try {
      _error = null;
      
      // Update UI immediately
      final task = nonCompleted.removeAt(oldIndex);
      nonCompleted.insert(newIndex, task);
      _tasks = [...nonCompleted, ...completedTasks];
      notifyListeners();

      // Update order in database
      for (int i = 0; i < nonCompleted.length; i++) {
        final taskToUpdate = nonCompleted[i];
        if (taskToUpdate.order != i) {
          await _db.updateTask(taskToUpdate.copyWith(order: i));
        }
      }

      // Update order on server
      final allProjectTaskIds = nonCompleted.map((t) => t.id!).toList();
      await ApiService.reorderTasks(_currentProject!.id!, allProjectTaskIds);
    } catch (e) {
      _error = 'Error reordering tasks: $e';
      notifyListeners();
      // If reorder fails, reload from the source of truth
      await _reloadCurrentTasks();
      rethrow;
    }
  }

  Future<void> syncData() async {
    try {
      _error = null;
      await ApiService.syncData();
      await _reloadCurrentTasks();
    } catch (e) {
      _error = 'Error syncing tasks: $e';
      notifyListeners();
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
    await loadTasks(project: _currentProject, customView: _currentCustomView);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}