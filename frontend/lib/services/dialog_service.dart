import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../widgets/add_project_dialog.dart';
import '../widgets/edit_project_dialog.dart';
import '../widgets/error_dialog.dart';
import '../providers/project_provider.dart';
import '../providers/view_provider.dart';

class DialogService {
  static void showAddProjectDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AddProjectDialog(
        onProjectAdded: () {
          ref.read(projectProvider.notifier).loadProjects();
        },
      ),
    );
  }

  static void showEditProjectDialog(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) {
    showDialog(
      context: context,
      builder: (context) => EditProjectDialog(
        project: project,
        onProjectUpdated: () {
          ref.read(projectProvider.notifier).loadProjects();
        },
      ),
    );
  }

  static void showErrorDialog(
    BuildContext context, {
    required String error,
    VoidCallback? onSync,
  }) {
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        error: error,
        onSync: onSync ?? () {},
      ),
    );
  }

  static Future<void> deleteProject(
    BuildContext context,
    WidgetRef ref,
    int projectId,
  ) async {
    try {
      final projectNotifier = ref.read(projectProvider.notifier);
      final viewNotifier = ref.read(viewProvider.notifier);
      await projectNotifier.deleteProject(projectId);
      viewNotifier.handleProjectDeleted(projectId);
    } catch (e) {
      if (context.mounted) {
        showErrorDialog(context, error: 'Error deleting project: $e');
      }
    }
  }
}