import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project.dart';
import '../services/api_service.dart';
import '../services/app_database.dart';
import '../services/logging_service.dart';
import 'service_providers.dart';
import 'task_provider.dart';

/// True while a background sync is running with cached data already visible.
/// The cold-start sync path (empty local DB) uses projectProvider's own
/// AsyncLoading state instead.
class SyncingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final syncingProvider = NotifierProvider<SyncingNotifier, bool>(
  SyncingNotifier.new,
);

class ProjectNotifier extends AsyncNotifier<List<Project>> {
  ApiService get _api => ref.read(apiServiceProvider);
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  Future<List<Project>> build() async {
    return await _syncAndGetProjects();
  }

  Future<List<Project>> _syncAndGetProjects() async {
    final localProjects = await _db.allProjects;

    if (localProjects.isEmpty) {
      // Cold start: nothing to show, block until sync finishes.
      final prefs = await SharedPreferences.getInstance();
      prefs.remove('sync_token');
      await _runSync();
      return _db.allProjects;
    }

    // Warm start: return cached immediately, refresh in background.
    _backgroundSync();
    return localProjects;
  }

  Future<void> _backgroundSync() async {
    ref.read(syncingProvider.notifier).set(true);
    try {
      await _runSync();
      state = AsyncData(await _db.allProjects);
      // Tasks were written to SQLite by applySyncResponse — nudge the
      // task view to pick up any deltas.
      ref.read(taskProvider.notifier).reloadCurrentTasks();
    } catch (e) {
      LoggingService.logger.warning('Background project sync failed: $e');
      // Keep cached data visible; the next foreground action can surface
      // a more specific error if needed.
    } finally {
      ref.read(syncingProvider.notifier).set(false);
    }
  }

  Future<void> _runSync() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('sync_token');
    // Old RFC3339 tokens won't parse as int — treat them as missing so
    // the new endpoint full-syncs from 0.
    if (token != null && int.tryParse(token) == null) {
      token = null;
    }
    while (true) {
      final response = await _api.fetchSyncData(token);
      await _db.applySyncResponse(response);
      token = response.syncToken;
      await prefs.setString('sync_token', token);
      if (!response.hasMore) break;
    }
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
