import 'package:dimaist/utils/events.dart';
import 'package:dimaist/widgets/left_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'dart:io' show Platform;
import 'widgets/add_project_dialog.dart';
import 'widgets/custom_view_widget.dart';
import 'widgets/project_list_widget.dart';
import 'services/app_database.dart';
import 'screens/task_screen.dart';
import 'services/api_service.dart';
import 'services/logging_service.dart';

import 'models/project.dart';
import 'widgets/edit_project_dialog.dart';
import 'widgets/error_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  LoggingService.setup();
  await trayManager.setIcon('assets/infinite.png');
  Menu menu = Menu(
    items: [MenuItem(key: 'exit_app', label: 'Exit App')],
  );
  await trayManager.setContextMenu(menu);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AppDatabase _db = AppDatabase();
  GlobalKey<TaskScreenState>? _currentTaskScreenKey;
  String? _selectedCustomView = 'Today';
  int? _selectedProjectId;
  bool _isLoading = true;
  List<Project> _projects = [];

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

  Future<void> _loadProjects() async {
    final projects = await _db.allProjects;
    if (mounted) {
      setState(() {
        _projects = projects;
      });
    }
  }

  Future<void> _loadInitialData() async {
    print('_loadInitialData: Starting initial data load...');
    try {
      print('_loadInitialData: Getting shared preferences...');
      final prefs = await SharedPreferences.getInstance();
      print('_loadInitialData: Loading projects from database...');
      final projects = await _db.allProjects;
      print('_loadInitialData: Loaded ${projects.length} projects from database');

      if (projects.isEmpty) {
        print('_loadInitialData: No projects found, performing initial sync...');
        prefs.remove('sync_token');
      }

      print('_loadInitialData: Syncing data with API...');
      await ApiService.syncData();
      print('_loadInitialData: Data sync completed successfully');

      await _loadProjects();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('_loadInitialData: Error occurred: $e');
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
          _loadProjects();
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
          _loadProjects();
        },
      ),
    );
  }

  Future<void> _deleteProject(int id) async {
    try {
      await ApiService.deleteProject(id);
      setState(() {
        _projects.removeWhere((p) => p.id == id);
        if (_selectedProjectId == id) {
          _selectedCustomView = 'Today';
          _selectedProjectId = null;
        }
      });
    } catch (e) {
      _showErrorDialog('Error deleting project: $e');
    }
  }

  void _setSelectedCustomView(String viewName) {
    setState(() {
      _selectedCustomView = viewName;
      _selectedProjectId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedProjectIndex = _selectedProjectId != null
        ? _projects.indexWhere((p) => p.id == _selectedProjectId)
        : -1;

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
              _setSelectedCustomView('Today');
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.keyU) {
              _setSelectedCustomView('Upcoming');
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.keyE) {
              _setSelectedCustomView('Next');
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        body: Row(
          children: [
            LeftBar(
              selectedView: _selectedCustomView,
              onCustomViewSelected: _setSelectedCustomView,
              onAddProject: _showAddProjectDialog,
              projectList: ProjectList(
                projects: _projects,
                selectedIndex: selectedProjectIndex,
                onProjectSelected: (index) {
                  setState(() {
                    _selectedCustomView = null;
                    _selectedProjectId = _projects[index].id;
                  });
                },
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final project = _projects.removeAt(oldIndex);
                  _projects.insert(newIndex, project);

                  setState(() {}); // Update UI immediately

                  try {
                    // Update order in the database
                    for (int i = 0; i < _projects.length; i++) {
                      final projectToUpdate = _projects[i];
                      if (projectToUpdate.order != i) {
                        await _db
                            .updateProject(projectToUpdate.copyWith(order: i));
                      }
                    }

                    await ApiService.reorderProjects(
                      _projects.map((p) => p.id!).toList(),
                    );
                  } catch (e) {
                    _showErrorDialog('Error reordering projects: $e');
                    // If reorder fails, reload from the source of truth
                    await _loadProjects();
                  }
                },
                onEdit: _showEditProjectDialog,
                onDelete: _deleteProject,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMainContent(_projects),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(List<Project> projects) {
    if (_selectedCustomView != null) {
      final view = CustomViewWidget.customViews
          .firstWhere((v) => v.name == _selectedCustomView);
      _currentTaskScreenKey = GlobalKey<TaskScreenState>();
      return TaskScreen(key: _currentTaskScreenKey, customView: view);
    }

    if (_selectedProjectId != null) {
      final project =
          projects.firstWhere((p) => p.id == _selectedProjectId, orElse: () {
        // Handle case where project is not found
        return projects.first;
      });
      _currentTaskScreenKey = GlobalKey<TaskScreenState>();
      return TaskScreen(key: _currentTaskScreenKey, project: project);
    }

    _currentTaskScreenKey = null;
    return const Center(
      child: Text('Select a project or view'),
    );
  }
}
