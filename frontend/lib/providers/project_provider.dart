import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../repositories/providers.dart';
import '../repositories/interfaces/project_repository_interface.dart';

class ProjectState {
  final List<Project> projects;
  final bool isLoading;
  final String? error;

  const ProjectState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });

  ProjectState copyWith({
    List<Project>? projects,
    bool? isLoading,
    String? error,
  }) {
    return ProjectState(
      projects: projects ?? this.projects,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class ProjectNotifier extends StateNotifier<ProjectState> {
  final IProjectRepository _repository;

  ProjectNotifier(this._repository) : super(const ProjectState());

  Future<void> loadProjects() async {
    try {
      state = state.copyWith(error: null);
      final projects = await _repository.getAllProjects();
      state = state.copyWith(projects: projects);
    } catch (e) {
      state = state.copyWith(error: 'Error loading projects: $e');
    }
  }

  /// Load projects with initial sync - replaces the initialization logic from MainScreen
  Future<void> loadProjectsWithSync() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final projects = await _repository.syncAndGetProjects();
      state = state.copyWith(projects: projects, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: 'Error loading initial data: $e', isLoading: false);
      rethrow;
    }
  }

  Future<void> addProject(String name, String color) async {
    try {
      state = state.copyWith(error: null);
      final createdProject = await _repository.createProject(name, color);
      final updatedProjects = [...state.projects, createdProject];
      state = state.copyWith(projects: updatedProjects);
    } catch (e) {
      state = state.copyWith(error: 'Error creating project: $e');
      rethrow;
    }
  }

  Future<void> updateProject(Project project) async {
    try {
      state = state.copyWith(error: null);
      await _repository.updateProject(project);

      final updatedProjects = state.projects
          .map((p) => p.id == project.id ? project : p)
          .toList();
      state = state.copyWith(projects: updatedProjects);
    } catch (e) {
      state = state.copyWith(error: 'Error updating project: $e');
      rethrow;
    }
  }

  Future<void> deleteProject(int id) async {
    try {
      state = state.copyWith(error: null);
      await _repository.deleteProject(id);
      final updatedProjects = state.projects.where((p) => p.id != id).toList();
      state = state.copyWith(projects: updatedProjects);
    } catch (e) {
      state = state.copyWith(error: 'Error deleting project: $e');
      rethrow;
    }
  }

  Future<void> reorderProjects(int oldIndex, int newIndex) async {
    try {
      state = state.copyWith(error: null);

      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final projects = [...state.projects];
      final project = projects.removeAt(oldIndex);
      projects.insert(newIndex, project);

      state = state.copyWith(projects: projects); // Update UI immediately

      await _repository.reorderProjects(projects.map((p) => p.id!).toList());
    } catch (e) {
      state = state.copyWith(error: 'Error reordering projects: $e');
      // If reorder fails, reload from the source of truth
      await loadProjects();
      rethrow;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final projectProvider = StateNotifierProvider<ProjectNotifier, ProjectState>((
  ref,
) {
  final repository = ref.watch(projectRepositoryProvider);
  return ProjectNotifier(repository);
});
