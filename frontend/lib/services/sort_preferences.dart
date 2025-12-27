import 'package:shared_preferences/shared_preferences.dart';
import '../enums/sort_mode.dart';
import '../widgets/custom_view_widget.dart';

class SortPreferences {
  static const String _projectPrefix = 'sort_mode_project_';
  static const String _todayKey = 'sort_mode_today';
  static const String _upcomingKey = 'sort_mode_upcoming';
  static const String _nextKey = 'sort_mode_next';
  static const String _allKey = 'sort_mode_all';

  static Future<SortMode> getSortModeForProject(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$_projectPrefix$projectId');
    return value != null ? SortMode.fromString(value) : SortMode.order;
  }

  static Future<void> setSortModeForProject(int projectId, SortMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_projectPrefix$projectId', mode.value);
  }

  static Future<SortMode> getSortModeForCustomView(BuiltInViewType viewType) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKeyForViewType(viewType);
    final value = prefs.getString(key);
    return value != null ? SortMode.fromString(value) : SortMode.order;
  }

  static Future<void> setSortModeForCustomView(BuiltInViewType viewType, SortMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKeyForViewType(viewType);
    await prefs.setString(key, mode.value);
  }

  static String _getKeyForViewType(BuiltInViewType viewType) {
    return switch (viewType) {
      BuiltInViewType.today => _todayKey,
      BuiltInViewType.upcoming => _upcomingKey,
      BuiltInViewType.next => _nextKey,
      BuiltInViewType.all => _allKey,
    };
  }
}