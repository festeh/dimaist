import '../../models/project.dart';

abstract class IProjectRepository {
  /// Get all projects from local database
  Future<List<Project>> getAllProjects();
  
  /// Sync with server and return updated projects list
  /// This handles initialization logic including sync token management
  Future<List<Project>> syncAndGetProjects();
  
  /// Create a new project
  Future<Project> createProject(String name, String color);
  
  /// Update an existing project
  Future<void> updateProject(Project project);
  
  /// Delete a project by ID
  Future<void> deleteProject(int id);
  
  /// Reorder projects by providing a list of project IDs in new order
  Future<void> reorderProjects(List<int> projectIds);
}