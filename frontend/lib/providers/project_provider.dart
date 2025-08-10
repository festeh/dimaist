import 'package:flutter/foundation.dart';
import '../models/project.dart';
import '../services/app_database.dart';
import '../services/api_service.dart';

class ProjectProvider extends ChangeNotifier {
  final AppDatabase _db = AppDatabase();
  List<Project> _projects = [];
  bool _isLoading = false;
  String? _error;

  List<Project> get projects => _projects;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadProjects() async {
    try {
      _error = null;
      _projects = await _db.allProjects;
      notifyListeners();
    } catch (e) {
      _error = 'Error loading projects: $e';
      notifyListeners();
    }
  }

  Future<void> addProject(String name, String color) async {
    try {
      _error = null;
      final newProject = Project(
        name: name,
        color: color,
        order: _projects.length,
      );
      
      final createdProject = await ApiService.createProject(newProject);
      _projects.add(createdProject);
      notifyListeners();
    } catch (e) {
      _error = 'Error creating project: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProject(Project project) async {
    try {
      _error = null;
      await ApiService.updateProject(project.id!, project);
      
      final index = _projects.indexWhere((p) => p.id == project.id);
      if (index != -1) {
        _projects[index] = project;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Error updating project: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteProject(int id) async {
    try {
      _error = null;
      await ApiService.deleteProject(id);
      _projects.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      _error = 'Error deleting project: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reorderProjects(int oldIndex, int newIndex) async {
    try {
      _error = null;
      
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final project = _projects.removeAt(oldIndex);
      _projects.insert(newIndex, project);
      
      notifyListeners(); // Update UI immediately

      // Update order in the database
      for (int i = 0; i < _projects.length; i++) {
        final projectToUpdate = _projects[i];
        if (projectToUpdate.order != i) {
          await _db.updateProject(projectToUpdate.copyWith(order: i));
        }
      }

      await ApiService.reorderProjects(
        _projects.map((p) => p.id!).toList(),
      );
    } catch (e) {
      _error = 'Error reordering projects: $e';
      notifyListeners();
      // If reorder fails, reload from the source of truth
      await loadProjects();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}