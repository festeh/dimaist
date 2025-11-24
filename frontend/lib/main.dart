import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import 'config/app_theme.dart';
import 'config/app_constants.dart';
import 'services/logging_service.dart';
import 'services/tray_service.dart';
import 'services/settings_service.dart';
import 'providers/project_provider.dart';
import 'providers/theme_provider.dart';
import 'widgets/app_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LoggingService.setup();
  await SettingsService.instance.init();

  // Only initialize tray service on desktop platforms
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    await TrayService.initialize();
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.create(themeMode),
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
  @override
  Widget build(BuildContext context) {
    final projectAsyncValue = ref.watch(projectProvider);

    return projectAsyncValue.when(
      data: (projects) => AppScaffold(projects: projects),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading projects: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(projectProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
