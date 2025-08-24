import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../providers/view_provider.dart';
import '../screens/task_screen.dart';

class MainContent extends ConsumerWidget {
  final List<Project> projects;

  const MainContent({
    super.key,
    required this.projects,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(viewProvider);
    final customView = viewState.currentCustomView;
    final project = viewState.currentProject;

    if (customView != null) {
      return TaskScreen(
        key: ValueKey('custom-${customView.name}'),
        customView: customView,
      );
    }

    if (project != null) {
      return TaskScreen(
        key: ValueKey('project-${project.id}'),
        project: project,
      );
    }

    return const Center(
      child: Text('Select a project or view'),
    );
  }
}