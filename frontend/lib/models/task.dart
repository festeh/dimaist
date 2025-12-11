import 'package:dimaist/utils/value_wrapper.dart';
import 'package:dimaist/services/logging_service.dart';

class Task {
  final int? id;
  final String title;
  final String? description;
  final int projectId;
  final DateTime? _dueDate;      // Private - use due/hasTime getters
  final DateTime? _dueDatetime;  // Private - use due/hasTime getters
  final DateTime? startDatetime;
  final DateTime? endDatetime;
  final List<String>? _labels;
  final int order;
  final DateTime? completedAt;
  final List<DateTime>? _reminders;
  final String? recurrence;
  final DateTime? createdAt;

  Task({
    this.id,
    required this.title,
    this.description,
    required this.projectId,
    DateTime? dueDate,
    DateTime? dueDatetime,
    this.startDatetime,
    this.endDatetime,
    List<String>? labels,
    required this.order,
    this.completedAt,
    List<DateTime>? reminders,
    this.recurrence,
    this.createdAt,
  }) : _dueDate = dueDate,
       _dueDatetime = dueDatetime,
       _labels = labels,
       _reminders = reminders,
       assert(
         dueDate == null || dueDatetime == null,
         'Cannot have both dueDate and dueDatetime',
       );

  // Unified getters - THE ONLY PUBLIC INTERFACE for due dates
  DateTime? get due => _dueDatetime ?? _dueDate;
  bool get hasTime => _dueDatetime != null;

  List<String> get labels => _labels ?? [];
  List<DateTime> get reminders => _reminders ?? [];

  static DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;

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

      // Check if this is a date-only string (no time component)
      // Date-only strings should NOT be converted to UTC to preserve the date
      final isDateOnly = !processedDateStr.contains('T') &&
                         !processedDateStr.contains(' ') &&
                         RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(processedDateStr);

      if (isDateOnly) {
        // Parse as local date and keep it that way
        return DateTime.parse(processedDateStr);
      }

      return DateTime.parse(processedDateStr).toUtc();
    } catch (e) {
      // Fallback: try parsing as-is
      try {
        final isDateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr);
        if (isDateOnly) {
          return DateTime.parse(dateStr);
        }
        return DateTime.parse(dateStr).toUtc();
      } catch (e2) {
        return null;
      }
    }
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    try {
      return Task(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        projectId: json['project_id'],
        dueDate: _parseDate(json['due_date']),
        dueDatetime: _parseDate(json['due_datetime']),
        startDatetime: _parseDate(json['start_datetime']),
        endDatetime: _parseDate(json['end_datetime']),
        labels: json['labels'] != null ? List<String>.from(json['labels']) : [],
        order: json['order'],
        completedAt: _parseDate(json['completed_at']),
        reminders: json['reminders'] != null
            ? (json['reminders'] as List<dynamic>)
                  .map((e) => _parseDate(e as String?))
                  .where((d) => d != null)
                  .cast<DateTime>()
                  .toList()
            : [],
        recurrence: json['recurrence'],
        createdAt: _parseDate(json['created_at']),
      );
    } catch (e) {
      LoggingService.logger.severe(
        'Task.fromJson: Error processing task JSON (id: ${json['id']}, title: "${json['title']}"): $e. Raw JSON: $json',
      );
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'project_id': projectId,
      'due_date': _dueDate?.toUtc().toIso8601String(),
      'due_datetime': _dueDatetime?.toUtc().toIso8601String(),
      'start_datetime': startDatetime?.toUtc().toIso8601String(),
      'end_datetime': endDatetime?.toUtc().toIso8601String(),
      'labels': labels,
      'order': order,
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'reminders': reminders.map((e) => e.toUtc().toIso8601String()).toList(),
      'recurrence': recurrence?.trim(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Task copyWith({
    int? id,
    String? title,
    ValueWrapper<String?>? description,
    int? projectId,
    ValueWrapper<DateTime?>? due,  // Unified due parameter
    bool? hasTime,                  // Whether due has specific time
    ValueWrapper<DateTime?>? startDatetime,
    ValueWrapper<DateTime?>? endDatetime,
    List<String>? labels,
    int? order,
    ValueWrapper<DateTime?>? completedAt,
    List<DateTime>? reminders,
    String? recurrence,
    DateTime? createdAt,
  }) {
    // Determine new due date/datetime values
    DateTime? newDueDate;
    DateTime? newDueDatetime;

    if (due != null) {
      // due parameter provided - use hasTime to determine which field
      final newHasTime = hasTime ?? this.hasTime;
      if (due.value != null && newHasTime) {
        newDueDatetime = due.value;
      } else if (due.value != null) {
        newDueDate = due.value;
      }
      // If due.value is null, both stay null (clearing due date)
    } else {
      // No due parameter - preserve existing values
      newDueDate = _dueDate;
      newDueDatetime = _dueDatetime;
    }

    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description != null ? description.value : this.description,
      projectId: projectId ?? this.projectId,
      dueDate: newDueDate,
      dueDatetime: newDueDatetime,
      startDatetime: startDatetime != null
          ? startDatetime.value
          : this.startDatetime,
      endDatetime: endDatetime != null ? endDatetime.value : this.endDatetime,
      labels: labels ?? this.labels,
      order: order ?? this.order,
      completedAt: completedAt != null ? completedAt.value : this.completedAt,
      reminders: reminders ?? this.reminders,
      recurrence: recurrence ?? this.recurrence,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
