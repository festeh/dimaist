import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../services/logging_service.dart';
import '../services/api_service.dart';
import '../services/app_database.dart';
import '../utils/value_wrapper.dart';
import 'interfaces/task_repository_interface.dart';

class TaskRepository implements ITaskRepository {
  final ApiService _apiService;
  final AppDatabase _database;

  TaskRepository({
    required ApiService apiService,
    required AppDatabase database,
  })  : _apiService = apiService,
        _database = database;

  @override
  Future<List<Task>> getTasksByProject(int projectId) async {
    return _database.getTasksByProject(projectId);
  }

  @override
  Future<List<Task>> getTodayTasks() async {
    return _database.getTodayTasks();
  }

  @override
  Future<List<Task>> getUpcomingTasks() async {
    return _database.getUpcomingTasks();
  }

  @override
  Future<List<Task>> getTasksByLabel(String label) async {
    return _database.getTasksByLabel(label);
  }

  @override
  Future<Task?> getTaskById(int id) async {
    return _database.getTaskById(id);
  }

  @override
  Future<Task> createTask(Task task) async {
    LoggingService.logger.info('TaskRepository: Creating task...');
    
    try {
      final createdTask = await _apiService.createTask(task);
      
      // Update local database after successful API call
      await _database.insertTask(createdTask);
      LoggingService.logger.info('TaskRepository: Task created successfully with ID ${createdTask.id}');
      return createdTask;
    } catch (e) {
      LoggingService.logger.severe('TaskRepository: Error creating task: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateTask(int id, Task task) async {
    LoggingService.logger.info('TaskRepository: Updating task $id...');
    
    try {
      await _apiService.updateTask(id, task);
      
      // Update local database after successful API call
      await _database.updateTask(task);
      LoggingService.logger.info('TaskRepository: Task $id updated successfully');
    } catch (e) {
      LoggingService.logger.severe('TaskRepository: Error updating task $id: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteTask(int id) async {
    LoggingService.logger.info('TaskRepository: Deleting task $id...');
    
    try {
      await _apiService.deleteTask(id);
      
      // Update local database after successful API call
      await _database.deleteTask(id);
      LoggingService.logger.info('TaskRepository: Task $id deleted successfully');
    } catch (e) {
      LoggingService.logger.severe('TaskRepository: Error deleting task $id: $e');
      rethrow;
    }
  }

  @override
  Future<void> completeTask(int id) async {
    LoggingService.logger.info('TaskRepository: Completing task $id...');
    
    try {
      await _apiService.completeTask(id);
      
      // Update local task completion status
      final task = await _database.getTaskById(id);
      if (task != null) {
        final updatedTask = task.copyWith(
          completedAt: ValueWrapper(DateTime.now()),
        );
        await _database.updateTask(updatedTask);
      }
      
      LoggingService.logger.info('TaskRepository: Task $id completed successfully');
    } catch (e) {
      LoggingService.logger.severe('TaskRepository: Error completing task $id: $e');
      rethrow;
    }
  }

  @override
  Future<void> reorderTasks(int projectId, List<int> taskIds) async {
    LoggingService.logger.info('TaskRepository: Reordering tasks for project $projectId...');
    
    try {
      // Update local task order first for immediate UI feedback
      final tasks = await _database.getTasksByProject(projectId);
      final nonCompletedTasks = tasks.where((task) => task.completedAt == null).toList();
      
      for (int i = 0; i < nonCompletedTasks.length; i++) {
        final taskToUpdate = nonCompletedTasks[i];
        if (taskToUpdate.order != i) {
          await _database.updateTask(taskToUpdate.copyWith(order: i));
        }
      }

      // Update order on server
      await _apiService.reorderTasks(projectId, taskIds);
      LoggingService.logger.info('TaskRepository: Tasks for project $projectId reordered successfully');
    } catch (e) {
      LoggingService.logger.severe('TaskRepository: Error reordering tasks for project $projectId: $e');
      rethrow;
    }
  }

  @override
  Future<void> syncTasks() async {
    LoggingService.logger.info('TaskRepository: Syncing tasks...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncToken = prefs.getString('sync_token');
      final syncResponse = await _apiService.fetchSyncData(syncToken);
      
      // Update database with sync data
      LoggingService.logger.info('TaskRepository: Upserting ${syncResponse.projects.length} projects...');
      for (var project in syncResponse.projects) {
        await _database.upsertProject(project);
      }

      LoggingService.logger.info('TaskRepository: Upserting ${syncResponse.tasks.length} tasks...');
      for (var task in syncResponse.tasks) {
        await _database.upsertTask(task);
      }

      // Save new sync token
      await prefs.setString('sync_token', syncResponse.syncToken);
      LoggingService.logger.info('TaskRepository: Tasks synced successfully');
    } catch (e) {
      LoggingService.logger.severe('TaskRepository: Error syncing tasks: $e');
      rethrow;
    }
  }

  @override
  Future<Project?> getDefaultProjectForToday() async {
    final projects = await _database.allProjects;
    final defaultProject = projects.where((p) => p.name == 'Inbox');
    
    if (defaultProject.isNotEmpty) {
      return defaultProject.first;
    }
    
    if (projects.isNotEmpty) {
      return projects.first;
    }
    
    throw Exception('No projects found');
  }
}