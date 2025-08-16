import 'package:dimaist/widgets/left_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'widgets/add_project_dialog.dart';
import 'widgets/project_list_widget.dart';
import 'screens/task_screen.dart';
import 'services/api_service.dart';
import 'services/logging_service.dart';
import 'services/tray_service.dart';
import 'utils/responsive_utils.dart';

import 'models/project.dart';
import 'widgets/edit_project_dialog.dart';
import 'widgets/error_dialog.dart';
import 'providers/project_provider.dart';
import 'providers/task_provider.dart';
import 'providers/view_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LoggingService.setup();
  
  // Only initialize tray service on desktop platforms
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    await TrayService.initialize();
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => ViewProvider()),
      ],
      child: MaterialApp(
        title: 'Dimaist',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF6200EE),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6200EE),
            brightness: Brightness.dark,
            secondary: const Color(0xFF03DAC6),
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          useMaterial3: true,
          textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme)
              .copyWith(
                headlineSmall: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                bodyLarge: const TextStyle(fontSize: 16, color: Colors.white),
                bodyMedium: const TextStyle(fontSize: 14, color: Colors.white),
              ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', 'GB'), // English, Great Britain
        ],
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  GlobalKey<TaskScreenState>? _currentTaskScreenKey;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;

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
    LoggingService.logger.info('_loadInitialData: Starting initial data load...');
    try {
      LoggingService.logger.info('_loadInitialData: Getting shared preferences...');
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
      
      LoggingService.logger.info('_loadInitialData: Loading projects from database...');
      await projectProvider.loadProjects();
      LoggingService.logger.info('_loadInitialData: Loaded ${projectProvider.projects.length} projects from database');

      if (projectProvider.projects.isEmpty) {
        LoggingService.logger.info('_loadInitialData: No projects found, performing initial sync...');
        prefs.remove('sync_token');
      }

      LoggingService.logger.info('_loadInitialData: Syncing data with API...');
      await ApiService.syncData();
      LoggingService.logger.info('_loadInitialData: Data sync completed successfully');

      await projectProvider.loadProjects();
      
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
          Provider.of<ProjectProvider>(context, listen: false).loadProjects();
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
          Provider.of<ProjectProvider>(context, listen: false).loadProjects();
        },
      ),
    );
  }

  Future<void> _deleteProject(int id) async {
    try {
      final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
      final viewProvider = Provider.of<ViewProvider>(context, listen: false);
      await projectProvider.deleteProject(id);
      viewProvider.handleProjectDeleted(id);
    } catch (e) {
      _showErrorDialog('Error deleting project: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer2<ProjectProvider, ViewProvider>(
      builder: (context, projectProvider, viewProvider, child) {
        final projects = projectProvider.projects;
        final selectedProjectIndex = viewProvider.getSelectedProjectIndex(projects);
        final isMobile = ResponsiveUtils.isMobile(context);

        final leftBarContent = LeftBar(
          selectedView: viewProvider.selectedCustomView,
          onCustomViewSelected: (view) {
            viewProvider.selectCustomView(view);
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
              viewProvider.selectProject(projects[index].id!);
              if (isMobile) {
                Navigator.of(context).pop();
              }
            },
            onReorder: (oldIndex, newIndex) async {
              try {
                await projectProvider.reorderProjects(oldIndex, newIndex);
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
                  viewProvider.selectCustomView('Today');
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.keyU) {
                  viewProvider.selectCustomView('Upcoming');
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.keyE) {
                  viewProvider.selectCustomView('Next');
                  return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: Scaffold(
            key: _scaffoldKey,
            appBar: isMobile ? _buildMobileAppBar(viewProvider) : null,
            drawer: isMobile ? Drawer(child: leftBarContent) : null,
            body: isMobile
                ? _buildMobileLayout(projects, viewProvider)
                : _buildDesktopLayout(projects, viewProvider, leftBarContent),
          ),
        );
      },
    );
  }

  AppBar _buildMobileAppBar(ViewProvider viewProvider) {
    String title = 'Dimaist';
    if (viewProvider.selectedCustomView != null) {
      title = viewProvider.selectedCustomView!;
    } else if (viewProvider.selectedProjectId != null) {
      final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
      final project = projectProvider.projects.firstWhere(
        (p) => p.id == viewProvider.selectedProjectId,
        orElse: () => Project(name: 'Dimaist', color: '#6200EE', order: 0),
      );
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
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            _currentTaskScreenKey?.currentState?.showAddTaskDialog();
          },
        ),
      ],
    );
  }

  Widget _buildMobileLayout(List<Project> projects, ViewProvider viewProvider) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return _buildMainContent(projects, viewProvider);
  }

  Widget _buildDesktopLayout(List<Project> projects, ViewProvider viewProvider, Widget leftBarContent) {
    return Row(
      children: [
        leftBarContent,
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildMainContent(projects, viewProvider),
        ),
      ],
    );
  }

  Widget _buildMainContent(List<Project> projects, ViewProvider viewProvider) {
    final viewSelection = viewProvider.getViewSelection(projects);
    
    if (viewSelection.isCustomView) {
      _currentTaskScreenKey = GlobalKey<TaskScreenState>();
      return TaskScreen(key: _currentTaskScreenKey, customView: viewSelection.customView);
    }

    if (viewSelection.isProject) {
      _currentTaskScreenKey = GlobalKey<TaskScreenState>();
      return TaskScreen(key: _currentTaskScreenKey, project: viewSelection.project);
    }

    _currentTaskScreenKey = null;
    return const Center(
      child: Text('Select a project or view'),
    );
  }
}
