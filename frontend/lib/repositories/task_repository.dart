import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../services/logging_service.dart';
import '../services/api_service.dart';
import '../services/app_database.dart';
import '../enums/sort_mode.dart';
import 'interfaces/task_repository_interface.dart';

class TaskRepository implements ITaskRepository {
  final ApiService _apiService;
  final AppDatabase _database;

  TaskRepository({
    required ApiService apiService,
    required AppDatabase database,
  }) : _apiService = apiService,
       _database = database;

  @override
  Future<List<Task>> getTasksByProject(int projectId, {SortMode sortMode = SortMode.order}) async {
    return _database.getTasksByProject(projectId, sortMode: sortMode);
  }

  @override
  Future<List<Task>> getTodayTasks({SortMode sortMode = SortMode.order}) async {
    return _database.getTodayTasks(sortMode: sortMode);
  }

  @override
  Future<List<Task>> getUpcomingTasks({SortMode sortMode = SortMode.order}) async {
    return _database.getUpcomingTasks(sortMode: sortMode);
  }

  @override
  Future<List<Task>> getTasksByLabel(String label, {SortMode sortMode = SortMode.order}) async {
    return _database.getTasksByLabel(label, sortMode: sortMode);
  }

  @override
  Future<List<Task>> getAllUncompletedTasks({SortMode sortMode = SortMode.order}) async {
    return _database.getAllUncompletedTasks(sortMode: sortMode);
  }

  @override
  Future<Task?> getTaskById(int id) async {
    return _database.getTaskById(id);
  }

  @override
  Future<(Task, String?)> createTask(Task task) async {
    LoggingService.logger.info('TaskRepository: Creating task...');

    try {
      final (createdTask, warning) = await _apiService.createTask(task);

      // Update local database after successful API call
      await _database.insertTask(createdTask);
      LoggingService.logger.info(
        'TaskRepository: Task created successfully with ID ${createdTask.id}',
      );
      return (createdTask, warning);
    } catch (e) {
      LoggingService.logger.severe('TaskRepository: Error creating task: $e');
      rethrow;
    }
  }

  @override
  Future<String?> updateTask(int id, Task task) async {
    LoggingService.logger.info('TaskRepository: Updating task $id...');

    try {
      final warning = await _apiService.updateTask(id, task);

      // Update local database after successful API call
      await _database.updateTask(task);
      LoggingService.logger.info(
        'TaskRepository: Task $id updated successfully',
      );
      return warning;
    } catch (e) {
      LoggingService.logger.severe(
        'TaskRepository: Error updating task $id: $e',
      );
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
      LoggingService.logger.info(
        'TaskRepository: Task $id deleted successfully',
      );
    } catch (e) {
      LoggingService.logger.severe(
        'TaskRepository: Error deleting task $id: $e',
      );
      rethrow;
    }
  }

  @override
  Future<void> completeTask(int id) async {
    LoggingService.logger.info('TaskRepository: Completing task $id...');

    try {
      await _apiService.completeTask(id);

      // Fetch the updated task from backend to get the correct state
      // (for recurring tasks, the backend updates due date and clears completion)
      final updatedTask = await _apiService.getTask(id);
      await _database.updateTask(updatedTask);

      LoggingService.logger.info(
        'TaskRepository: Task $id completed successfully. Updated with new state from backend.',
      );
    } catch (e) {
      LoggingService.logger.severe(
        'TaskRepository: Error completing task $id: $e',
      );
      rethrow;
    }
  }

  @override
  Future<void> reorderTasks(int projectId, List<int> taskIds) async {
    LoggingService.logger.info(
      'TaskRepository: Reordering tasks for project $projectId...',
    );

    try {
      // Update order on server
      await _apiService.reorderTasks(projectId, taskIds);
      LoggingService.logger.info(
        'TaskRepository: Tasks for project $projectId reordered successfully',
      );
    } catch (e) {
      LoggingService.logger.severe(
        'TaskRepository: Error reordering tasks for project $projectId: $e',
      );
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
      LoggingService.logger.info(
        'TaskRepository: Upserting ${syncResponse.projects.length} projects...',
      );
      for (var project in syncResponse.projects) {
        await _database.upsertProject(project);
      }

      LoggingService.logger.info(
        'TaskRepository: Upserting ${syncResponse.tasks.length} tasks...',
      );
      for (var task in syncResponse.tasks) {
        await _database.upsertTask(task);
      }

      // Handle deleted items
      LoggingService.logger.info(
        'TaskRepository: Deleting ${syncResponse.deletedProjectIds.length} projects...',
      );
      for (var projectId in syncResponse.deletedProjectIds) {
        await _database.deleteProject(projectId);
      }

      LoggingService.logger.info(
        'TaskRepository: Deleting ${syncResponse.deletedTaskIds.length} tasks...',
      );
      for (var taskId in syncResponse.deletedTaskIds) {
        await _database.deleteTask(taskId);
      }

      // Save new sync token
      await prefs.setString('sync_token', syncResponse.syncToken);
      LoggingService.logger.info('TaskRepository: Data synced successfully');
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

  @override
  Future<void> fullResync() async {
    LoggingService.logger.info('TaskRepository: Starting full resync...');

    try {
      // Clear local database
      await _database.clearDatabase();
      LoggingService.logger.info('TaskRepository: Local database cleared');

      // Clear sync token to force full sync
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sync_token');
      LoggingService.logger.info('TaskRepository: Sync token cleared');

      // Fetch all data from server
      final syncResponse = await _apiService.fetchSyncData(null);

      // Insert all projects
      LoggingService.logger.info(
        'TaskRepository: Inserting ${syncResponse.projects.length} projects...',
      );
      for (var project in syncResponse.projects) {
        await _database.upsertProject(project);
      }

      // Insert all tasks
      LoggingService.logger.info(
        'TaskRepository: Inserting ${syncResponse.tasks.length} tasks...',
      );
      for (var task in syncResponse.tasks) {
        await _database.upsertTask(task);
      }

      // Save new sync token
      await prefs.setString('sync_token', syncResponse.syncToken);
      LoggingService.logger.info('TaskRepository: Full resync completed');
    } catch (e) {
      LoggingService.logger.severe('TaskRepository: Error during full resync: $e');
      rethrow;
    }
  }
}
