import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/asr_service.dart';
import '../services/app_database.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final asrServiceProvider = Provider<AsrService>((ref) {
  return AsrService();
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});
