import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dimaist/models/project.dart' as project_model;
import 'package:dimaist/models/task.dart' as task_model;
import '../enums/sort_mode.dart';

part 'app_database.g.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}

@UseRowClass(project_model.Project)
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get order => integer()();
  TextColumn get color => text().withDefault(const Constant('grey'))();
  TextColumn get icon => text().nullable()();
}

class ListOfStringConverter extends TypeConverter<List<String>?, String?> {
  const ListOfStringConverter();

  @override
  List<String>? fromSql(String? fromDb) {
    if (fromDb == null || fromDb.isEmpty) return null;

    return fromDb.split(',').where((s) => s.isNotEmpty).toList();
  }

  @override
  String? toSql(List<String>? value) {
    if (value == null) return null;

    return value.join(',');
  }
}

class ListOfDateTimeConverter extends TypeConverter<List<DateTime>?, String?> {
  const ListOfDateTimeConverter();

  static DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;

    try {
      String processedDateStr = dateStr;

      // Handle invalid dates like "0001-01-01T00:53:28+00:53"

      if (dateStr.startsWith('0001-01-01')) {
        return null;
      }

      // Fix malformed timezone formats

      if (dateStr.contains('+') && dateStr.length > 6) {
        // Handle +00:53 format (should be +00:53:00 or just skip)

        final tzMatch = RegExp(r'\+(\d{2}):(\d{2})$').firstMatch(dateStr);

        if (tzMatch != null) {
          final minutes = tzMatch.group(2)!;

          // If it's not a standard timezone offset, convert to UTC

          if (minutes != '00' && minutes != '30' && minutes != '45') {
            processedDateStr = dateStr.replaceFirst(
              RegExp(r'\+\d{2}:\d{2}$'),
              'Z',
            );
          }
        }
      }

      // Handle RFC3339 format like "2025-07-08 23:59:00+000"

      // Convert to proper ISO 8601 format

      if (dateStr.contains('+') && !dateStr.contains('T')) {
        processedDateStr = dateStr.replaceFirst(' ', 'T');

        // Fix timezone format: +000 -> +00:00

        if (processedDateStr.endsWith('+000')) {
          processedDateStr = processedDateStr.replaceFirst('+000', '+00:00');
        }
      }

      return DateTime.parse(processedDateStr);
    } catch (e) {
      // Fallback: try parsing as-is

      try {
        return DateTime.parse(dateStr);
      } catch (e2) {
        return null;
      }
    }
  }

  @override
  List<DateTime>? fromSql(String? fromDb) {
    if (fromDb == null || fromDb.trim().isEmpty) return null;

    return fromDb
        .split(',')
        .map((e) => _parseDate(e.trim()))
        .where((d) => d != null)
        .cast<DateTime>()
        .toList();
  }

  @override
  String? toSql(List<DateTime>? value) {
    if (value == null) return null;

    return value.map((e) => e.toIso8601String()).join(',');
  }
}

@UseRowClass(task_model.Task)
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
  IntColumn get projectId => integer()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get dueDatetime => dateTime().nullable()();
  DateTimeColumn get startDatetime => dateTime().nullable()();
  DateTimeColumn get endDatetime => dateTime().nullable()();
  TextColumn get labels =>
      text().map(const ListOfStringConverter()).nullable()();
  IntColumn get order => integer()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get reminders =>
      text().map(const ListOfDateTimeConverter()).nullable()();
  TextColumn get recurrence => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
}

@DriftDatabase(tables: [Projects, Tasks])
class AppDatabase extends _$AppDatabase {
  static AppDatabase? _instance;

  AppDatabase._internal() : super(_openConnection());

  factory AppDatabase() {
    _instance ??= AppDatabase._internal();
    return _instance!;
  }

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 3) {
        // Migration removed - notes feature was killed
      }
      if (from == 3) {
        // Migration from 3 to .dart, id is now auto-increment
      }
      if (from == 4) {
        // Migration from 4 to 5, createdAt and updatedAt are now nullable
      }
      if (from < 6) {
        // Migration to 6: Add icon column to projects
        await m.addColumn(projects, projects.icon);
      }
      if (from < 7) {
        // Migration to 7: Add createdAt column to tasks
        await m.addColumn(tasks, tasks.createdAt);
      }
    },
  );

  // Project methods
  Future<List<project_model.Project>> get allProjects => (select(
    projects,
  )..orderBy([(p) => OrderingTerm(expression: p.order)])).get();

  ProjectsCompanion _projectToCompanion(project_model.Project project) {
    return ProjectsCompanion(
      id: project.id != null ? Value(project.id!) : const Value.absent(),
      name: Value(project.name),
      order: Value(project.order),
      color: Value(project.color),
      icon: Value(project.icon),
    );
  }

  Future<void> insertProject(project_model.Project project) =>
      into(projects).insert(_projectToCompanion(project));

  Future<void> updateProject(project_model.Project project) =>
      (update(projects)..where((p) => p.id.equals(project.id!))).write(
        _projectToCompanion(project),
      );

  Future<void> deleteProject(int id) =>
      (delete(projects)..where((p) => p.id.equals(id))).go();

  Future<void> upsertProject(project_model.Project project) async {
    await into(projects).insertOnConflictUpdate(_projectToCompanion(project));
  }

  // Task methods
  Future<List<task_model.Task>> getTasksByProject(int projectId, {SortMode sortMode = SortMode.order}) {
    final query = select(tasks)..where((t) => t.projectId.equals(projectId));

    if (sortMode == SortMode.dueDate) {
      query.orderBy([
        (t) => OrderingTerm(expression: t.dueDate, nulls: NullsOrder.last),
        (t) => OrderingTerm(expression: t.dueDatetime, nulls: NullsOrder.last),
        (t) => OrderingTerm(expression: t.order),
      ]);
    } else {
      query.orderBy([(t) => OrderingTerm(expression: t.order)]);
    }

    return query.get();
  }

  Future<List<task_model.Task>> getTodayTasks({SortMode sortMode = SortMode.order}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayEnd = today.add(const Duration(days: 1));

    final query = select(tasks)
      ..where(
        (t) =>
            t.completedAt.isNull() &
            ((t.dueDate.isNotNull() & t.dueDate.isSmallerThan(Variable(todayEnd))) |
             (t.dueDatetime.isNotNull() & t.dueDatetime.isSmallerThan(Variable(todayEnd)))),
      );

    if (sortMode == SortMode.dueDate) {
      query.orderBy([
        (t) => OrderingTerm(expression: t.dueDate, nulls: NullsOrder.last),
        (t) => OrderingTerm(expression: t.dueDatetime, nulls: NullsOrder.last),
        (t) => OrderingTerm(expression: t.order),
      ]);
    } else {
      query.orderBy([(t) => OrderingTerm(expression: t.order)]);
    }

    return query.get();
  }

  Future<List<task_model.Task>> getUpcomingTasks({SortMode sortMode = SortMode.order}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysFromNow = today.add(const Duration(days: 7));
    final tomorrow = today.add(const Duration(days: 1));

    final query = select(tasks)
      ..where((t) {
        final dueDateClause =
            t.dueDate.isNotNull() &
            t.dueDate.isBetweenValues(tomorrow, sevenDaysFromNow);
        final dueDatetimeClause =
            t.dueDatetime.isNotNull() &
            t.dueDatetime.isBetweenValues(tomorrow, sevenDaysFromNow);
        return t.completedAt.isNull() & (dueDateClause | dueDatetimeClause);
      });

    if (sortMode == SortMode.dueDate) {
      query.orderBy([
        (t) => OrderingTerm(expression: t.dueDate, nulls: NullsOrder.last),
        (t) => OrderingTerm(expression: t.dueDatetime, nulls: NullsOrder.last),
        (t) => OrderingTerm(expression: t.order),
      ]);
    } else {
      query.orderBy([(t) => OrderingTerm(expression: t.order)]);
    }

    return query.get();
  }

  Future<List<task_model.Task>> getTasksByLabel(String label, {SortMode sortMode = SortMode.order}) {
    final query = select(tasks)
      ..where((t) => t.completedAt.isNull() & t.labels.like('%$label%'));

    if (sortMode == SortMode.dueDate) {
      query.orderBy([
        (t) => OrderingTerm(expression: t.dueDate, nulls: NullsOrder.last),
        (t) => OrderingTerm(expression: t.dueDatetime, nulls: NullsOrder.last),
        (t) => OrderingTerm(expression: t.order),
      ]);
    } else {
      query.orderBy([(t) => OrderingTerm(expression: t.order)]);
    }

    return query.get();
  }

  Future<task_model.Task?> getTaskById(int id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  TasksCompanion _taskToCompanion(task_model.Task task) {
    // Derive dueDate/dueDatetime from unified getters
    DateTime? dueDate;
    DateTime? dueDatetime;
    if (task.due != null) {
      if (task.hasTime) {
        dueDatetime = task.due;
      } else {
        dueDate = task.due;
      }
    }

    return TasksCompanion(
      id: task.id != null ? Value(task.id!) : const Value.absent(),
      description: Value(task.description),
      projectId: Value(task.projectId),
      dueDate: Value(dueDate),
      dueDatetime: Value(dueDatetime),
      startDatetime: Value(task.startDatetime),
      endDatetime: Value(task.endDatetime),
      labels: Value(task.labels),
      order: Value(task.order),
      completedAt: Value(task.completedAt),
      reminders: Value(task.reminders),
      recurrence: Value(task.recurrence),
      createdAt: Value(task.createdAt),
    );
  }

  Future<void> insertTask(task_model.Task task) =>
      into(tasks).insert(_taskToCompanion(task));

  Future<void> updateTask(task_model.Task task) => (update(
    tasks,
  )..where((t) => t.id.equals(task.id!))).write(_taskToCompanion(task));

  Future<void> deleteTask(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<void> upsertTask(task_model.Task task) async {
    await into(tasks).insertOnConflictUpdate(_taskToCompanion(task));
  }

  Future<void> clearDatabase() async {
    await transaction(() async {
      await customStatement('PRAGMA foreign_keys = OFF');
      await delete(tasks).go();
      await delete(projects).go();
      await customStatement('PRAGMA foreign_keys = ON');
    });
  }
}
