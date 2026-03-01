import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart';
import '../services/api_service.dart';
import '../services/app_database.dart';
import 'service_providers.dart';

class ProjectNotifier extends AsyncNotifier<List<Project>> {
  ApiService get _api => ref.read(apiServiceProvider);
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  Future<List<Project>> build() async {
    return await _syncAndGetProjects();
  }

  Future<List<Project>> _syncAndGetProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final localProjects = await _db.allProjects;

    if (localProjects.isEmpty) {
      prefs.remove('sync_token');
    }

    final syncToken = prefs.getString('sync_token');
    final syncResponse = await _api.fetchSyncData(syncToken);
    await _db.applySyncResponse(syncResponse);
    await prefs.setString('sync_token', syncResponse.syncToken);

    return _db.allProjects;
  }

  Future<void> loadProjects() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _db.allProjects);
  }

  Future<void> addProject(String name, String color, String? icon) async {
    state = await AsyncValue.guard(() async {
      final newProject = Project(
        name: name,
        color: color,
        icon: icon,
        order: (await _db.allProjects).length,
      );
      final createdProject = await _api.createProject(newProject);
      await _db.insertProject(createdProject);
      final currentProjects = state.value ?? [];
      return [...currentProjects, createdProject];
    });
  }

  Future<void> updateProject(Project project) async {
    state = await AsyncValue.guard(() async {
      await _api.updateProject(project.id!, project);
      await _db.updateProject(project);
      final currentProjects = state.value ?? [];
      return currentProjects
          .map((p) => p.id == project.id ? project : p)
          .toList();
    });
  }

  Future<void> deleteProject(int id) async {
    state = await AsyncValue.guard(() async {
      await _api.deleteProject(id);
      await _db.deleteProject(id);
      final currentProjects = state.value ?? [];
      return currentProjects.where((p) => p.id != id).toList();
    });
  }

  Future<void> reorderProjects(int oldIndex, int newIndex) async {
    state = await AsyncValue.guard(() async {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final currentProjects = state.value ?? [];
      final projects = [...currentProjects];
      final project = projects.removeAt(oldIndex);
      projects.insert(newIndex, project);

      await _api.reorderProjects(projects.map((p) => p.id!).toList());
      return projects;
    });
  }
}

final projectProvider = AsyncNotifierProvider<ProjectNotifier, List<Project>>(
  () => ProjectNotifier(),
);
