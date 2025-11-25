import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/app_database.dart';
import '../services/asr_service.dart';
import 'interfaces/project_repository_interface.dart';
import 'interfaces/task_repository_interface.dart';
import 'project_repository.dart';
import 'task_repository.dart';

/// Service providers
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final asrServiceProvider = Provider<AsrService>((ref) {
  return AsrService();
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Repository providers
final projectRepositoryProvider = Provider<IProjectRepository>((ref) {
  return ProjectRepository(
    apiService: ref.watch(apiServiceProvider),
    database: ref.watch(appDatabaseProvider),
  );
});

final taskRepositoryProvider = Provider<ITaskRepository>((ref) {
  return TaskRepository(
    apiService: ref.watch(apiServiceProvider),
    database: ref.watch(appDatabaseProvider),
  );
});
