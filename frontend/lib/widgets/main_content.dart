import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/app_bar_config.dart';
import '../providers/view_provider.dart';
import '../providers/search_provider.dart';
import '../screens/task_screen.dart';
import '../screens/search_results_screen.dart';

class MainContent extends ConsumerWidget {
  final List<Project> projects;
  final Function(AppBarConfig?)? onAppBarConfigChanged;

  const MainContent({
    super.key,
    required this.projects,
    this.onAppBarConfigChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(viewProvider);
    final searchState = ref.watch(searchProvider);
    final customView = viewState.currentCustomView;
    final project = viewState.currentProject;

    // Show search results when search is active
    if (searchState.isSearchActive) {
      return const SearchResultsScreen();
    }

    if (customView != null) {
      return TaskScreen(
        key: ValueKey('custom-${customView.name}'),
        customView: customView,
        onAppBarConfigChanged: onAppBarConfigChanged,
      );
    }

    if (project != null) {
      return TaskScreen(
        key: ValueKey('project-${project.id}'),
        project: project,
        onAppBarConfigChanged: onAppBarConfigChanged,
      );
    }

    // Clear app bar config when no view is selected
    onAppBarConfigChanged?.call(
      const AppBarConfig(title: Text('Select a project or view')),
    );

    return const Center(child: Text('Select a project or view'));
  }
}
