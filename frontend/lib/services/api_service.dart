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

  Future<void> sendTextAIStream(
    String text,
    String model,
    Function(String) onChunk,
    Function() onDone, {
    Function(String)? onStatus,
  }) async {
    _logger.info('Sending text AI streaming request...', {
      'text': text,
      'model': model,
    });

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/ai/text'));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = json.encode({'text': text, 'model': model});

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
                  // This contains the actual response text
                  if (eventPayload is Map<String, dynamic>) {
                    final responseText = eventPayload['response'] as String?;
                    if (responseText != null && responseText.isNotEmpty) {
                      onChunk(responseText);
                    }
                  }
                  onDone();
                  return; // Exit the stream processing
                case 'error':
                  // Handle error events
                  if (eventPayload is Map<String, dynamic>) {
                    final errorMsg =
                        eventPayload['error'] as String? ?? 'Unknown error';
                    onChunk('Error: $errorMsg');
                  }
                  onDone();
                  return;
                case 'tool_call':
                case 'tool_result':
                  // These are intermediate events, we could show them as progress
                  // For now, just log them
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

  Future<void> sendAudio(List<int> audioBytes, String model) async {
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
      request.fields['model'] = model;
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

  Future<void> sendAudioStream(
    List<int> audioBytes,
    String model,
    Function(String) onChunk,
    Function() onDone, {
    Function(String)? onStatus,
    Function(String)? onTranscription,
  }) async {
    _logger.info('Sending audio streaming request...', {'model': model});

    final client = http.Client();
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/ai/audio'),
      );
      request.headers['Accept'] = 'text/event-stream';
      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: 'audio.wav',
        ),
      );
      request.fields['model'] = model;

      final response = await client.send(request);

      if (response.statusCode == 200) {
        _logger.info('Audio streaming request successful.');

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
                case 'transcription':
                  // Handle transcription event
                  if (onTranscription != null &&
                      eventPayload is Map<String, dynamic>) {
                    final transcribedText = eventPayload['text'] as String?;
                    if (transcribedText != null) {
                      onTranscription(transcribedText);
                    }
                  }
                  break;
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
                  // This contains the actual response text
                  if (eventPayload is Map<String, dynamic>) {
                    final responseText = eventPayload['response'] as String?;
                    if (responseText != null && responseText.isNotEmpty) {
                      onChunk(responseText);
                    }
                  }
                  onDone();
                  return; // Exit the stream processing
                case 'error':
                  // Handle error events
                  if (eventPayload is Map<String, dynamic>) {
                    final errorMsg =
                        eventPayload['error'] as String? ?? 'Unknown error';
                    onChunk('Error: $errorMsg');
                  }
                  onDone();
                  return;
                case 'tool_call':
                case 'tool_result':
                  // These are intermediate events, we could show them as progress
                  // For now, just log them
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
          'Failed to send audio streaming request: ${response.statusCode}',
        );
        throw Exception('Failed to send audio streaming request');
      }
    } catch (e) {
      _logger.severe('Error sending audio streaming request: $e');
      rethrow;
    } finally {
      client.close();
    }
  }
}
