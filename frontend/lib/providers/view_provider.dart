import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/custom_view_widget.dart';
import '../models/project.dart';

// Sealed class hierarchy for view selection
sealed class ViewSelection {
  const ViewSelection();
}

class CustomViewSelection extends ViewSelection {
  final CustomView customView;
  const CustomViewSelection(this.customView);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomViewSelection && other.customView.name == customView.name;

  @override
  int get hashCode => customView.name.hashCode;
}

class ProjectViewSelection extends ViewSelection {
  final Project project;
  const ProjectViewSelection(this.project);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectViewSelection && other.project.id == project.id;

  @override
  int get hashCode => project.id.hashCode;
}

class ViewState {
  final ViewSelection currentSelection;

  const ViewState({ViewSelection? currentSelection})
    : currentSelection =
          currentSelection ??
          const CustomViewSelection(CustomView(BuiltInViewType.today));

  ViewState copyWith({ViewSelection? currentSelection}) {
    return ViewState(
      currentSelection: currentSelection ?? this.currentSelection,
    );
  }

  bool get hasCustomViewSelected => currentSelection is CustomViewSelection;
  bool get hasProjectSelected => currentSelection is ProjectViewSelection;

  CustomView? get currentCustomView => currentSelection is CustomViewSelection
      ? (currentSelection as CustomViewSelection).customView
      : null;

  Project? get currentProject => currentSelection is ProjectViewSelection
      ? (currentSelection as ProjectViewSelection).project
      : null;
}

class ViewNotifier extends StateNotifier<ViewState> {
  ViewNotifier() : super(const ViewState());

  Project? getCurrentProject(List<Project> projects) {
    final project = state.currentProject;
    if (project == null) return null;

    try {
      return projects.firstWhere((p) => p.id == project.id);
    } catch (e) {
      // If project not found, fallback to first project or null
      return projects.isNotEmpty ? projects.first : null;
    }
  }

  int getSelectedProjectIndex(List<Project> projects) {
    final project = state.currentProject;
    if (project == null) return -1;
    return projects.indexWhere((p) => p.id == project.id);
  }

  void selectCustomView(String viewName) {
    final customView = CustomViewWidget.customViews.firstWhere(
      (v) => v.name == viewName,
      orElse: () => CustomViewWidget.customViews.first,
    );
    state = state.copyWith(currentSelection: CustomViewSelection(customView));
  }

  void selectProject(Project project) {
    state = state.copyWith(currentSelection: ProjectViewSelection(project));
  }

  void resetToToday() {
    const todayView = CustomView(BuiltInViewType.today);
    state = state.copyWith(currentSelection: CustomViewSelection(todayView));
  }

  // Handle when a project is deleted
  void handleProjectDeleted(int deletedProjectId) {
    final currentProject = state.currentProject;
    if (currentProject != null && currentProject.id == deletedProjectId) {
      resetToToday();
    }
  }
}

final viewProvider = StateNotifierProvider<ViewNotifier, ViewState>((ref) {
  return ViewNotifier();
});
