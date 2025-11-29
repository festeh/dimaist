import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../repositories/providers.dart';
import '../repositories/interfaces/project_repository_interface.dart';

class ProjectNotifier extends AsyncNotifier<List<Project>> {
  IProjectRepository get _repository => ref.read(projectRepositoryProvider);

  @override
  Future<List<Project>> build() async {
    return await _repository.syncAndGetProjects();
  }

  Future<void> loadProjects() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getAllProjects());
  }

  Future<void> addProject(String name, String color, String? icon) async {
    state = await AsyncValue.guard(() async {
      final createdProject = await _repository.createProject(name, color, icon);
      final currentProjects = state.valueOrNull ?? [];
      return [...currentProjects, createdProject];
    });
  }

  Future<void> updateProject(Project project) async {
    state = await AsyncValue.guard(() async {
      await _repository.updateProject(project);
      final currentProjects = state.valueOrNull ?? [];
      return currentProjects
          .map((p) => p.id == project.id ? project : p)
          .toList();
    });
  }

  Future<void> deleteProject(int id) async {
    state = await AsyncValue.guard(() async {
      await _repository.deleteProject(id);
      final currentProjects = state.valueOrNull ?? [];
      return currentProjects.where((p) => p.id != id).toList();
    });
  }

  Future<void> reorderProjects(int oldIndex, int newIndex) async {
    state = await AsyncValue.guard(() async {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final currentProjects = state.valueOrNull ?? [];
      final projects = [...currentProjects];
      final project = projects.removeAt(oldIndex);
      projects.insert(newIndex, project);

      await _repository.reorderProjects(projects.map((p) => p.id!).toList());
      return projects;
    });
  }
}

final projectProvider = AsyncNotifierProvider<ProjectNotifier, List<Project>>(
  () => ProjectNotifier(),
);
