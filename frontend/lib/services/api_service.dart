import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/project.dart';
import '../models/task.dart';
import '../models/sync_response.dart';
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

  Future<void> sendTextAIStream(
    List<Map<String, dynamic>> messages,
    String provider,
    String model,
    Function(String, {double? duration}) onChunk,
    Function() onDone, {
    Function(String)? onStatus,
    Function(String, {double? duration})? onToolCall,
    Function(String, {double? duration})? onToolResult,
  }) async {
    _logger.info('Sending text AI streaming request...', {
      'messages_count': messages.length,
      'provider': provider,
      'model': model,
    });

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/ai/text'));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = json.encode({
        'messages': messages,
        'provider': provider,
        'model': model,
      });

      final response = await client.send(request);

      if (response.statusCode == 200) {
        _logger.info('Text AI streaming request successful.');

        await for (final chunk
            in response.stream
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          if (chunk.startsWith('data: ')) {
            final data = chunk.substring(6);
            if (data.trim().isEmpty) continue;

            try {
              final eventData = json.decode(data);
              final event = eventData['event'] as String?;
              final eventPayload = eventData['data'];

              _logger.fine(
                'Received SSE event: $event with data: $eventPayload',
              );

              switch (event) {
                case 'thinking':
                  // Show progress messages
                  if (onStatus != null &&
                      eventPayload is Map<String, dynamic>) {
                    final message = eventPayload['message'] as String?;
                    if (message != null) {
                      onStatus(message);
                    }
                  }
                  break;
                case 'final_response':
                  // This contains the actual response text and optional duration
                  if (eventPayload is Map<String, dynamic>) {
                    final responseText = eventPayload['response'] as String?;
                    final duration = eventPayload['duration'] as double?;
                    if (responseText != null && responseText.isNotEmpty) {
                      onChunk(responseText, duration: duration);
                    }
                  }
                  onDone();
                  return; // Exit the stream processing
                case 'error':
                  // Handle error events
                  if (eventPayload is Map<String, dynamic>) {
                    final errorMsg =
                        eventPayload['error'] as String? ?? 'Unknown error';
                    final duration = eventPayload['duration'] as double?;
                    onChunk('Error: $errorMsg', duration: duration);
                  }
                  onDone();
                  return;
                case 'tool_call':
                  // Handle tool call events
                  if (onToolCall != null &&
                      eventPayload is Map<String, dynamic>) {
                    final tool = eventPayload['tool'] as String? ?? 'unknown';
                    final arguments =
                        eventPayload['arguments'] as String? ?? '';
                    final duration = eventPayload['duration'] as double?;
                    // Format the tool call with both tool name and arguments
                    final formattedCall =
                        'Function: $tool\n${arguments.isNotEmpty ? 'Arguments: $arguments' : 'No arguments'}';
                    onToolCall(formattedCall, duration: duration);
                  }
                  break;
                case 'tool_result':
                  // Handle tool result events
                  if (onToolResult != null &&
                      eventPayload is Map<String, dynamic>) {
                    final result = eventPayload['result'] as String? ?? '';
                    final duration = eventPayload['duration'] as double?;
                    onToolResult(
                      result,
                      duration: duration,
                    ); // Pass full result with duration
                  }
                  break;
                default:
                  _logger.fine('Unknown SSE event type: $event');
              }
            } catch (e) {
              // Skip non-JSON lines or malformed data
              _logger.fine('Skipping malformed SSE data: $data, error: $e');
            }
          }
        }

        // If we reach here without getting a final_response, call onDone anyway
        onDone();
      } else {
        _logger.warning(
          'Failed to send text AI streaming request: ${response.statusCode}',
        );
        throw Exception('Failed to send text AI streaming request');
      }
    } catch (e) {
      _logger.severe('Error sending text AI streaming request: $e');
      rethrow;
    } finally {
      client.close();
    }
  }
}
