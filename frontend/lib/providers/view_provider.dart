import 'package:flutter/foundation.dart';
import '../widgets/custom_view_widget.dart';
import '../models/project.dart';

class ViewProvider extends ChangeNotifier {
  String? _selectedCustomView = 'Today';
  int? _selectedProjectId;

  String? get selectedCustomView => _selectedCustomView;
  int? get selectedProjectId => _selectedProjectId;

  bool get hasCustomViewSelected => _selectedCustomView != null;
  bool get hasProjectSelected => _selectedProjectId != null;

  CustomView? get currentCustomView {
    if (_selectedCustomView == null) return null;
    return CustomViewWidget.customViews.firstWhere(
      (v) => v.name == _selectedCustomView,
      orElse: () => CustomViewWidget.customViews.first,
    );
  }

  Project? getCurrentProject(List<Project> projects) {
    if (_selectedProjectId == null) return null;
    try {
      return projects.firstWhere((p) => p.id == _selectedProjectId);
    } catch (e) {
      // If project not found, fallback to first project or null
      return projects.isNotEmpty ? projects.first : null;
    }
  }

  int getSelectedProjectIndex(List<Project> projects) {
    if (_selectedProjectId == null) return -1;
    return projects.indexWhere((p) => p.id == _selectedProjectId);
  }

  void selectCustomView(String viewName) {
    _selectedCustomView = viewName;
    _selectedProjectId = null;
    notifyListeners();
  }

  void selectProject(int projectId) {
    _selectedCustomView = null;
    _selectedProjectId = projectId;
    notifyListeners();
  }

  void clearSelection() {
    _selectedCustomView = null;
    _selectedProjectId = null;
    notifyListeners();
  }

  void resetToToday() {
    _selectedCustomView = 'Today';
    _selectedProjectId = null;
    notifyListeners();
  }

  // Handle when a project is deleted
  void handleProjectDeleted(int deletedProjectId) {
    if (_selectedProjectId == deletedProjectId) {
      resetToToday();
    }
  }

  // Get the appropriate view/project for TaskProvider
  ViewSelection getViewSelection(List<Project> projects) {
    if (hasCustomViewSelected) {
      return ViewSelection.customView(currentCustomView!);
    } else if (hasProjectSelected) {
      final project = getCurrentProject(projects);
      return ViewSelection.project(project!);
    } else {
      // Fallback to Today view
      return ViewSelection.customView(
        CustomViewWidget.customViews.firstWhere((v) => v.name == 'Today'),
      );
    }
  }
}

class ViewSelection {
  final CustomView? customView;
  final Project? project;

  const ViewSelection._({this.customView, this.project});

  factory ViewSelection.customView(CustomView view) {
    return ViewSelection._(customView: view);
  }

  factory ViewSelection.project(Project project) {
    return ViewSelection._(project: project);
  }

  bool get isCustomView => customView != null;
  bool get isProject => project != null;
}