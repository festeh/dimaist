import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../providers/view_provider.dart';
import '../providers/project_provider.dart';
import '../services/dialog_service.dart';
import '../utils/responsive_utils.dart';
import '../widgets/left_bar.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/project_list_widget.dart';
import '../widgets/mobile_layout.dart';
import '../widgets/desktop_layout.dart';
import '../widgets/keyboard_shortcuts_handler.dart';
import '../screens/task_screen.dart';

class AppScaffold extends ConsumerStatefulWidget {
  final List<Project> projects;

  const AppScaffold({
    super.key,
    required this.projects,
  });

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  GlobalKey<TaskScreenState>? _taskScreenKey;

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(viewProvider);
    final viewNotifier = ref.read(viewProvider.notifier);
    final isMobile = ResponsiveUtils.isMobile(context);

    // Update task screen key when view changes
    final customView = viewState.currentCustomView;
    final project = viewState.currentProject;
    if (customView != null || project != null) {
      _taskScreenKey = GlobalKey<TaskScreenState>();
    }

    final leftBarContent = _buildLeftBar(
      context,
      viewState,
      viewNotifier,
      isMobile,
    );

    final layout = isMobile
        ? MobileLayout(
            projects: widget.projects,
            leftBarContent: leftBarContent,
          )
        : DesktopLayout(
            projects: widget.projects,
            leftBarContent: leftBarContent,
          );

    return KeyboardShortcutsHandler(
      taskScreenKey: _taskScreenKey,
      child: layout,
    );
  }

  Widget _buildLeftBar(
    BuildContext context,
    ViewState viewState,
    ViewNotifier viewNotifier,
    bool isMobile,
  ) {
    final selectedProjectIndex = viewNotifier.getSelectedProjectIndex(widget.projects);

    return LeftBar(
      selectedView: viewState.currentCustomView?.name,
      onCustomViewSelected: (view) {
        viewNotifier.selectCustomView(view);
        if (isMobile) {
          Navigator.of(context).pop();
        }
      },
      onAddProject: () {
        if (isMobile) {
          Navigator.of(context).pop();
        }
        DialogService.showAddProjectDialog(context, ref);
      },
      onOpenSettings: () {
        if (isMobile) {
          Navigator.of(context).pop();
        }
        showDialog(
          context: context,
          builder: (context) => const SettingsDialog(),
        );
      },
      projectList: ProjectList(
        projects: widget.projects,
        selectedIndex: selectedProjectIndex,
        onProjectSelected: (index) {
          viewNotifier.selectProject(widget.projects[index]);
          if (isMobile) {
            Navigator.of(context).pop();
          }
        },
        onReorder: (oldIndex, newIndex) async {
          try {
            await ref.read(projectProvider.notifier).reorderProjects(oldIndex, newIndex);
          } catch (e) {
            if (mounted) {
              DialogService.showErrorDialog(
                context,
                error: 'Error reordering projects: $e',
              );
            }
          }
        },
        onEdit: (project) => DialogService.showEditProjectDialog(context, ref, project),
        onDelete: (id) => DialogService.deleteProject(context, ref, id),
      ),
    );
  }
}