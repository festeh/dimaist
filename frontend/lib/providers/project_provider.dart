import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../services/app_database.dart';
import '../services/api_service.dart';

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
  final AppDatabase _db = AppDatabase();

  ProjectNotifier() : super(const ProjectState());

  Future<void> loadProjects() async {
    try {
      state = state.copyWith(error: null);
      final projects = await _db.allProjects;
      state = state.copyWith(projects: projects);
    } catch (e) {
      state = state.copyWith(error: 'Error loading projects: $e');
    }
  }

  Future<void> addProject(String name, String color) async {
    try {
      state = state.copyWith(error: null);
      final newProject = Project(
        name: name,
        color: color,
        order: state.projects.length,
      );

      final createdProject = await ApiService.createProject(newProject);
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
      await ApiService.updateProject(project.id!, project);

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
      await ApiService.deleteProject(id);
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

      // Update order in the database
      for (int i = 0; i < projects.length; i++) {
        final projectToUpdate = projects[i];
        if (projectToUpdate.order != i) {
          await _db.updateProject(projectToUpdate.copyWith(order: i));
        }
      }

      await ApiService.reorderProjects(projects.map((p) => p.id!).toList());
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
  return ProjectNotifier();
});
