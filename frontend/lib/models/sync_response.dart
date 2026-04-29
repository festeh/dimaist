import 'project.dart';
import 'task.dart';

class SyncResponse {
  final List<Project> projects;
  final List<Task> tasks;
  final String syncToken;
  final bool hasMore;

  const SyncResponse({
    required this.projects,
    required this.tasks,
    required this.syncToken,
    required this.hasMore,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    final projectsData = json['projects'] as List?;
    final projects = (projectsData ?? [])
        .map((p) => Project.fromJson(p as Map<String, dynamic>))
        .toList();

    final tasksData = json['tasks'] as List?;
    final tasks = (tasksData ?? [])
        .map((t) => Task.fromJson(t as Map<String, dynamic>))
        .toList();

    return SyncResponse(
      projects: projects,
      tasks: tasks,
      syncToken: json['sync_token'] as String,
      hasMore: (json['has_more'] as bool?) ?? false,
    );
  }
}
