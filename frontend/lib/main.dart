import 'package:dimaist/widgets/left_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'widgets/add_project_dialog.dart';
import 'widgets/project_list_widget.dart';
import 'widgets/custom_view_widget.dart';
import 'screens/task_screen.dart';
import 'services/api_service.dart';
import 'services/logging_service.dart';
import 'services/tray_service.dart';
import 'utils/responsive_utils.dart';

import 'models/project.dart';
import 'widgets/edit_project_dialog.dart';
import 'widgets/error_dialog.dart';
import 'providers/project_provider.dart';
import 'providers/view_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LoggingService.setup();

  // Only initialize tray service on desktop platforms
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    await TrayService.initialize();
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.darkTheme(context),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'GB')],
      home: const MainScreen(),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  GlobalKey<TaskScreenState>? _currentTaskScreenKey;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  String? _lastViewKey; // Track the current view to detect changes

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(error: error, onSync: () {}),
    );
  }

  Future<void> _loadInitialData() async {
    LoggingService.logger.info(
      '_loadInitialData: Starting initial data load...',
    );
    try {
      LoggingService.logger.info(
        '_loadInitialData: Getting shared preferences...',
      );
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final projectNotifier = ref.read(projectProvider.notifier);

      LoggingService.logger.info(
        '_loadInitialData: Loading projects from database...',
      );
      await projectNotifier.loadProjects();
      final projects = ref.read(projectProvider).projects;
      LoggingService.logger.info(
        '_loadInitialData: Loaded ${projects.length} projects from database',
      );

      if (projects.isEmpty) {
        LoggingService.logger.info(
          '_loadInitialData: No projects found, performing initial sync...',
        );
        prefs.remove('sync_token');
      }

      LoggingService.logger.info('_loadInitialData: Syncing data with API...');
      await ApiService.syncData();
      LoggingService.logger.info(
        '_loadInitialData: Data sync completed successfully',
      );

      await projectNotifier.loadProjects();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      LoggingService.logger.severe('_loadInitialData: Error occurred: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showErrorDialog('Error loading initial data: $e');
    }
  }

  void _showAddProjectDialog() {
    showDialog(
      context: context,
      builder: (context) => AddProjectDialog(
        onProjectAdded: () {
          ref.read(projectProvider.notifier).loadProjects();
        },
      ),
    );
  }

  void _showEditProjectDialog(Project project) {
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

  Future<void> _deleteProject(int id) async {
    try {
      final projectNotifier = ref.read(projectProvider.notifier);
      final viewNotifier = ref.read(viewProvider.notifier);
      await projectNotifier.deleteProject(id);
      viewNotifier.handleProjectDeleted(id);
    } catch (e) {
      _showErrorDialog('Error deleting project: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(projectProvider);
    final viewState = ref.watch(viewProvider);
    final viewNotifier = ref.read(viewProvider.notifier);
    final projectNotifier = ref.read(projectProvider.notifier);

    final projects = projectState.projects;
    final selectedProjectIndex = viewNotifier.getSelectedProjectIndex(projects);
    final isMobile = ResponsiveUtils.isMobile(context);

    final leftBarContent = LeftBar(
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
        _showAddProjectDialog();
      },
      projectList: ProjectList(
        projects: projects,
        selectedIndex: selectedProjectIndex,
        onProjectSelected: (index) {
          viewNotifier.selectProject(projects[index]);
          if (isMobile) {
            Navigator.of(context).pop();
          }
        },
        onReorder: (oldIndex, newIndex) async {
          try {
            await projectNotifier.reorderProjects(oldIndex, newIndex);
          } catch (e) {
            _showErrorDialog('Error reordering projects: $e');
          }
        },
        onEdit: _showEditProjectDialog,
        onDelete: _deleteProject,
      ),
    );

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final isControlPressed = HardwareKeyboard.instance.isControlPressed;
          final isAltPressed = HardwareKeyboard.instance.isAltPressed;
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
          final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;

          if (!isControlPressed &&
              !isAltPressed &&
              !isShiftPressed &&
              !isMetaPressed) {
            if (event.logicalKey == LogicalKeyboardKey.keyN &&
                Platform.isLinux) {
              _currentTaskScreenKey?.currentState?.showAddTaskDialog();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.keyT) {
              viewNotifier.selectCustomView(BuiltInViewType.today.displayName);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.keyU) {
              viewNotifier.selectCustomView(
                BuiltInViewType.upcoming.displayName,
              );
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.keyE) {
              viewNotifier.selectCustomView(BuiltInViewType.next.displayName);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: isMobile ? _buildMobileAppBar(viewState, viewNotifier) : null,
        drawer: isMobile
            ? Drawer(child: SafeArea(child: leftBarContent))
            : null,
        body: SafeArea(
          child: isMobile
              ? _buildMobileLayout(projects, viewState, viewNotifier)
              : _buildDesktopLayout(
                  projects,
                  viewState,
                  viewNotifier,
                  leftBarContent,
                ),
        ),
      ),
    );
  }

  AppBar _buildMobileAppBar(ViewState viewState, ViewNotifier viewNotifier) {
    String title = AppConstants.appName;
    final customView = viewState.currentCustomView;
    final project = viewState.currentProject;

    if (customView != null) {
      title = customView.name;
    } else if (project != null) {
      title = project.name;
    }

    return AppBar(
      title: Text(title),
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
    );
  }

  Widget _buildMobileLayout(
    List<Project> projects,
    ViewState viewState,
    ViewNotifier viewNotifier,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return _buildMainContent(projects, viewState, viewNotifier);
  }

  Widget _buildDesktopLayout(
    List<Project> projects,
    ViewState viewState,
    ViewNotifier viewNotifier,
    Widget leftBarContent,
  ) {
    return Row(
      children: [
        leftBarContent,
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildMainContent(projects, viewState, viewNotifier),
        ),
      ],
    );
  }

  Widget _buildMainContent(
    List<Project> projects,
    ViewState viewState,
    ViewNotifier viewNotifier,
  ) {
    final customView = viewState.currentCustomView;
    final project = viewState.currentProject;

    if (customView != null) {
      final currentViewKey = 'custom-${customView.name}';
      if (_lastViewKey != currentViewKey) {
        _currentTaskScreenKey = GlobalKey<TaskScreenState>();
        _lastViewKey = currentViewKey;
      }
      return TaskScreen(key: _currentTaskScreenKey, customView: customView);
    }

    if (project != null) {
      final currentViewKey = 'project-${project.id}';
      if (_lastViewKey != currentViewKey) {
        _currentTaskScreenKey = GlobalKey<TaskScreenState>();
        _lastViewKey = currentViewKey;
      }
      return TaskScreen(key: _currentTaskScreenKey, project: project);
    }

    _currentTaskScreenKey = null;
    _lastViewKey = null;
    return const Center(child: Text('Select a project or view'));
  }
}
