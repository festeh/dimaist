import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/project.dart';
import '../models/task.dart';
import '../models/sync_response.dart';
import 'logging_service.dart';

class ApiService {
  final String baseUrl;
  final _logger = LoggingService.logger;

  ApiService({
    String? baseUrl,
  })  : baseUrl = baseUrl ?? const String.fromEnvironment(
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
        _logger.fine('ApiService.fetchSyncData: Response body: ${response.body}');
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

  Future<Task> createTask(Task task) async {
    _logger.info('Creating task...');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(task.toJson()),
      );
      if (response.statusCode == 200) {
        _logger.info('Task created successfully.');
        final newTask = Task.fromJson(json.decode(response.body));
        return newTask;
      } else {
        _logger.warning('Failed to create task: ${response.statusCode}');
        throw Exception('Failed to create task');
      }
    } catch (e) {
      _logger.severe('Error creating task: $e');
      rethrow;
    }
  }

  Future<void> updateTask(int id, Task task) async {
    _logger.info('Updating task $id...');
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/tasks/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(task.toJson()),
      );
      if (response.statusCode != 200) {
        _logger.warning('Failed to update task $id: ${response.statusCode}');
        throw Exception('Failed to update task');
      }

      _logger.info('Task $id updated successfully.');
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

  Future<void> sendAudio(List<int> audioBytes) async {
    _logger.info('Sending audio...');
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/ai/audio'),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: 'audio.wav',
        ),
      );
      final response = await request.send();
      if (response.statusCode == 200) {
        _logger.info('Audio sent successfully.');
        final responseBody = await response.stream.bytesToString();
        LoggingService.logger.info(
          'Voice AI transcription result: $responseBody',
        );
        final decoded = json.decode(responseBody);
        LoggingService.logger.info('Transcription: ${decoded['content']}');
      } else {
        _logger.warning('Failed to send audio: ${response.statusCode}');
        throw Exception('Failed to send audio');
      }
    } catch (e) {
      _logger.severe('Error sending audio: $e');
      rethrow;
    }
  }
}
