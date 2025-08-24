import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart';
import '../services/logging_service.dart';
import '../services/api_service.dart';
import '../services/app_database.dart';
import 'interfaces/project_repository_interface.dart';

class ProjectRepository implements IProjectRepository {
  final ApiService _apiService;
  final AppDatabase _database;

  ProjectRepository({
    required ApiService apiService,
    required AppDatabase database,
  })  : _apiService = apiService,
        _database = database;

  @override
  Future<List<Project>> getAllProjects() async {
    return _database.allProjects;
  }

  @override
  Future<List<Project>> syncAndGetProjects() async {
    LoggingService.logger.info('ProjectRepository: Starting sync and load...');
    
    try {
      LoggingService.logger.info('ProjectRepository: Getting shared preferences...');
      final prefs = await SharedPreferences.getInstance();
      
      LoggingService.logger.info('ProjectRepository: Loading projects from database...');
      final localProjects = await _database.allProjects;
      LoggingService.logger.info('ProjectRepository: Loaded ${localProjects.length} projects from database');

      // Clear sync token if no local projects (first time or fresh install)
      if (localProjects.isEmpty) {
        LoggingService.logger.info('ProjectRepository: No projects found, clearing sync token...');
        prefs.remove('sync_token');
      }

      LoggingService.logger.info('ProjectRepository: Syncing data with API...');
      final syncToken = prefs.getString('sync_token');
      final syncResponse = await _apiService.fetchSyncData(syncToken);
      LoggingService.logger.info('ProjectRepository: Data sync completed successfully');

      // Update database with sync data
      LoggingService.logger.info('ProjectRepository: Upserting ${syncResponse.projects.length} projects...');
      for (var project in syncResponse.projects) {
        LoggingService.logger.fine('ProjectRepository: Upserting project: $project');
        await _database.upsertProject(project);
      }

      LoggingService.logger.info('ProjectRepository: Upserting ${syncResponse.tasks.length} tasks...');
      for (var task in syncResponse.tasks) {
        LoggingService.logger.fine('ProjectRepository: Upserting task: $task');
        await _database.upsertTask(task);
      }

      // Save new sync token
      LoggingService.logger.info('ProjectRepository: Saving sync token: ${syncResponse.syncToken}');
      await prefs.setString('sync_token', syncResponse.syncToken);

      // Return fresh projects after sync
      final syncedProjects = await _database.allProjects;
      LoggingService.logger.info('ProjectRepository: Returning ${syncedProjects.length} synced projects');
      
      return syncedProjects;
    } catch (e) {
      LoggingService.logger.severe('ProjectRepository: Error during sync: $e');
      rethrow;
    }
  }

  @override
  Future<Project> createProject(String name, String color) async {
    LoggingService.logger.info('ProjectRepository: Creating project "$name"...');
    
    try {
      final newProject = Project(
        name: name,
        color: color,
        order: (await _database.allProjects).length,
      );

      final createdProject = await _apiService.createProject(newProject);
      
      // Update local database after successful API call
      await _database.insertProject(createdProject);
      LoggingService.logger.info('ProjectRepository: Project created successfully with ID ${createdProject.id}');
      
      return createdProject;
    } catch (e) {
      LoggingService.logger.severe('ProjectRepository: Error creating project: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateProject(Project project) async {
    LoggingService.logger.info('ProjectRepository: Updating project ${project.id}...');
    
    try {
      await _apiService.updateProject(project.id!, project);
      
      // Update local database after successful API call
      await _database.updateProject(project);
      LoggingService.logger.info('ProjectRepository: Project ${project.id} updated successfully');
    } catch (e) {
      LoggingService.logger.severe('ProjectRepository: Error updating project ${project.id}: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteProject(int id) async {
    LoggingService.logger.info('ProjectRepository: Deleting project $id...');
    
    try {
      await _apiService.deleteProject(id);
      
      // Update local database after successful API call
      await _database.deleteProject(id);
      LoggingService.logger.info('ProjectRepository: Project $id deleted successfully');
    } catch (e) {
      LoggingService.logger.severe('ProjectRepository: Error deleting project $id: $e');
      rethrow;
    }
  }

  @override
  Future<void> reorderProjects(List<int> projectIds) async {
    LoggingService.logger.info('ProjectRepository: Reordering projects...');
    
    try {
      await _apiService.reorderProjects(projectIds);
      LoggingService.logger.info('ProjectRepository: Projects reordered successfully');
    } catch (e) {
      LoggingService.logger.severe('ProjectRepository: Error reordering projects: $e');
      rethrow;
    }
  }
}