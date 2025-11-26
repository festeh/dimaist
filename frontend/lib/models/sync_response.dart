import 'project.dart';
import 'task.dart';

class SyncResponse {
  final List<Project> projects;
  final List<Task> tasks;
  final List<int> deletedProjectIds;
  final List<int> deletedTaskIds;
  final String syncToken;

  const SyncResponse({
    required this.projects,
    required this.tasks,
    required this.deletedProjectIds,
    required this.deletedTaskIds,
    required this.syncToken,
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

    final deletedProjectIds =
        (json['deleted_project_ids'] as List?)?.cast<int>() ?? [];
    final deletedTaskIds =
        (json['deleted_task_ids'] as List?)?.cast<int>() ?? [];

    return SyncResponse(
      projects: projects,
      tasks: tasks,
      deletedProjectIds: deletedProjectIds,
      deletedTaskIds: deletedTaskIds,
      syncToken: json['sync_token'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projects': projects.map((p) => p.toJson()).toList(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'deleted_project_ids': deletedProjectIds,
      'deleted_task_ids': deletedTaskIds,
      'sync_token': syncToken,
    };
  }
}
