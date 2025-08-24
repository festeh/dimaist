import '../../models/task.dart';
import '../../models/project.dart';

abstract class ITaskRepository {
  /// Get tasks for a specific project
  Future<List<Task>> getTasksByProject(int projectId);
  
  /// Get tasks due today
  Future<List<Task>> getTodayTasks();
  
  /// Get upcoming tasks
  Future<List<Task>> getUpcomingTasks();
  
  /// Get tasks by label
  Future<List<Task>> getTasksByLabel(String label);
  
  /// Get a specific task by ID
  Future<Task?> getTaskById(int id);
  
  /// Create a new task
  Future<Task> createTask(Task task);
  
  /// Update an existing task
  Future<void> updateTask(int id, Task task);
  
  /// Delete a task by ID
  Future<void> deleteTask(int id);
  
  /// Complete a task (handles recurring tasks on server)
  Future<void> completeTask(int id);
  
  /// Reorder tasks within a project
  Future<void> reorderTasks(int projectId, List<int> taskIds);
  
  /// Sync all tasks with server
  Future<void> syncTasks();
  
  /// Get default project for creating new tasks (e.g., Inbox)
  Future<Project?> getDefaultProjectForToday();
}