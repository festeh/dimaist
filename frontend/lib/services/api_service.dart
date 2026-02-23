import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_model.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/sync_response.dart';
import '../models/search_result.dart';
import 'logging_service.dart';

class ApiService {
  final String baseUrl;
  final _logger = LoggingService.logger;

  ApiService({String? baseUrl})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'BASE_URL',
            defaultValue: 'http://localhost:3000',
          );

  Future<SyncResponse> fetchSyncData([String? syncToken]) async {
    _logger.info('Fetching sync data...');

    Uri uri = Uri.parse('$baseUrl/sync');
    if (syncToken != null) {
      uri = uri.replace(queryParameters: {'sync_token': syncToken});
      _logger.info('Fetching with sync token: $syncToken');
    } else {
      _logger.info('No sync token provided, performing full sync.');
    }

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        _logger.fine(
          'ApiService.fetchSyncData: Response body: ${response.body}',
        );
        final data = json.decode(response.body);
        _logger.fine('ApiService.fetchSyncData: Parsed data: $data');

        final syncResponse = SyncResponse.fromJson(data);
        _logger.info(
          'Received ${syncResponse.projects.length} projects and ${syncResponse.tasks.length} tasks. New sync token: ${syncResponse.syncToken}',
        );

        return syncResponse;
      } else {
        _logger.severe('Failed to fetch sync data: ${response.statusCode}');
        throw Exception('Failed to fetch sync data: ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Error during sync data fetch: $e');
      rethrow;
    }
  }

  /// Creates a task and returns (task, warning) tuple.
  /// Warning is non-null if calendar sync failed.
  Future<(Task, String?)> createTask(Task task) async {
    _logger.info('Creating task...');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(task.toJson()),
      );
      if (response.statusCode == 200) {
        _logger.info('Task created successfully.');
        final data = json.decode(response.body);
        final newTask = Task.fromJson(data['task']);
        final warning = data['warning'] as String?;
        if (warning != null) {
          _logger.warning('Task created with warning: $warning');
        }
        return (newTask, warning);
      } else {
        _logger.warning('Failed to create task: ${response.statusCode}');
        // Try to parse error response
        String errorMessage = 'Failed to create task';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic> && errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // If parsing fails, use response body as-is or default message
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      _logger.severe('Error creating task: $e');
      rethrow;
    }
  }

  /// Updates a task and returns a warning if calendar sync failed.
  Future<String?> updateTask(int id, Task task) async {
    _logger.info('Updating task $id...');
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/tasks/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(task.toJson()),
      );
      if (response.statusCode != 200) {
        _logger.warning('Failed to update task $id: ${response.statusCode}');
        // Try to parse error response
        String errorMessage = 'Failed to update task';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic> && errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // If parsing fails, use response body as-is or default message
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }
        throw Exception(errorMessage);
      }

      _logger.info('Task $id updated successfully.');

      // Check for warning in response body
      if (response.body.isNotEmpty) {
        try {
          final data = json.decode(response.body);
          final warning = data['warning'] as String?;
          if (warning != null) {
            _logger.warning('Task updated with warning: $warning');
          }
          return warning;
        } catch (e) {
          // No valid JSON, that's fine
        }
      }
      return null;
    } catch (e) {
      _logger.severe('Error updating task $id: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(int id) async {
    _logger.info('Deleting task $id...');
    try {
      final response = await http.delete(Uri.parse('$baseUrl/tasks/$id'));
      if (response.statusCode != 200) {
        _logger.warning('Failed to delete task $id: ${response.statusCode}');
        throw Exception('Failed to delete task');
      }
      _logger.info('Task $id deleted successfully.');
    } catch (e) {
      _logger.severe('Error deleting task $id: $e');
      rethrow;
    }
  }

  Future<Project> createProject(Project project) async {
    _logger.info('Creating project...');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/projects'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(project.toJson()),
      );
      if (response.statusCode == 200) {
        _logger.info('Project created successfully.');
        final newProject = Project.fromJson(json.decode(response.body));
        return newProject;
      } else {
        _logger.warning('Failed to create project: ${response.statusCode}');
        throw Exception('Failed to create project');
      }
    } catch (e) {
      _logger.severe('Error creating project: $e');
      rethrow;
    }
  }

  Future<void> updateProject(int id, Project project) async {
    _logger.info('Updating project $id...');
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/projects/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(project.toJson()),
      );
      if (response.statusCode != 200) {
        _logger.warning('Failed to update project $id: ${response.statusCode}');
        throw Exception('Failed to update project');
      }
      _logger.info('Project $id updated successfully.');
    } catch (e) {
      _logger.severe('Error updating project $id: $e');
      rethrow;
    }
  }

  Future<void> deleteProject(int id) async {
    _logger.info('Deleting project $id...');
    try {
      final response = await http.delete(Uri.parse('$baseUrl/projects/$id'));
      if (response.statusCode != 200) {
        _logger.warning('Failed to delete project $id: ${response.statusCode}');
        throw Exception('Failed to delete project');
      }
      _logger.info('Project $id deleted successfully.');
    } catch (e) {
      _logger.severe('Error deleting project $id: $e');
      rethrow;
    }
  }

  Future<void> reorderProjects(List<int> projectIds) async {
    _logger.info('Reordering projects...', projectIds);
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/projects-reorder'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(projectIds),
      );
      if (response.statusCode != 200) {
        _logger.warning('Failed to reorder projects: ${response.statusCode}');
        throw Exception('Failed to reorder projects');
      }
      _logger.info('Projects reordered successfully.');
    } catch (e) {
      _logger.severe('Error reordering projects: $e');
      rethrow;
    }
  }

  Future<void> reorderTasks(int projectId, List<int> taskIds) async {
    _logger.info('Reordering tasks for project $projectId...', taskIds);
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/projects/$projectId/tasks/reorder'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(taskIds),
      );
      if (response.statusCode != 200) {
        _logger.warning(
          'Failed to reorder tasks for project $projectId: ${response.statusCode}',
        );
        throw Exception('Failed to reorder tasks');
      }
      _logger.info('Tasks for project $projectId reordered successfully.');
    } catch (e) {
      _logger.severe('Error reordering tasks for project $projectId: $e');
      rethrow;
    }
  }

  Future<Task> getTask(int id) async {
    _logger.info('Fetching task $id...');
    try {
      final response = await http.get(Uri.parse('$baseUrl/tasks/$id'));
      if (response.statusCode == 200) {
        _logger.info('Task $id fetched successfully.');
        return Task.fromJson(json.decode(response.body));
      } else {
        _logger.warning('Failed to fetch task $id: ${response.statusCode}');
        throw Exception('Failed to fetch task');
      }
    } catch (e) {
      _logger.severe('Error fetching task $id: $e');
      rethrow;
    }
  }

  Future<void> completeTask(int id) async {
    _logger.info('Completing task $id...');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks/$id/complete'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        _logger.info('Task $id completed successfully.');
      } else {
        _logger.warning('Failed to complete task $id: ${response.statusCode}');
        throw Exception('Failed to complete task');
      }
    } catch (e) {
      _logger.severe('Error completing task $id: $e');
      rethrow;
    }
  }

  Future<SearchResponse> search(String query) async {
    _logger.info('Searching for: $query');

    if (query.isEmpty) {
      return SearchResponse(results: [], count: 0);
    }

    try {
      final uri = Uri.parse('$baseUrl/find').replace(
        queryParameters: {'q': query},
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final searchResponse = SearchResponse.fromJson(data);
        _logger.info('Search found ${searchResponse.count} results');
        return searchResponse;
      } else {
        _logger.warning('Failed to search: ${response.statusCode}');
        throw Exception('Failed to search');
      }
    } catch (e) {
      _logger.severe('Error during search: $e');
      rethrow;
    }
  }

  Future<List<AiModel>> fetchAiModels() async {
    _logger.info('Fetching AI models...');
    try {
      final response = await http.get(Uri.parse('$baseUrl/ai/models'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = (data['data'] as List)
            .map((e) => AiModel.fromModelsResponse(e as Map<String, dynamic>))
            .toList();
        _logger.info('Fetched ${models.length} AI models');
        return models;
      } else {
        _logger.warning('Failed to fetch AI models: ${response.statusCode}');
        throw Exception('Failed to fetch AI models');
      }
    } catch (e) {
      _logger.severe('Error fetching AI models: $e');
      rethrow;
    }
  }
}
