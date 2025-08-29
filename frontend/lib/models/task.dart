import 'package:dimaist/utils/value_wrapper.dart';
import 'package:dimaist/services/logging_service.dart';

class Task {
  final int? id;
  final String description;
  final int projectId;
  final DateTime? dueDate;
  final DateTime? dueDatetime;
  final DateTime? startDatetime;
  final DateTime? endDatetime;
  final List<String>? _labels;
  final int order;
  final DateTime? completedAt;
  final List<DateTime>? _reminders;
  final String? recurrence;

  Task({
    this.id,
    required this.description,
    required this.projectId,
    this.dueDate,
    this.dueDatetime,
    this.startDatetime,
    this.endDatetime,
    List<String>? labels,
    required this.order,
    this.completedAt,
    List<DateTime>? reminders,
    this.recurrence,
  }) : _labels = labels,
       _reminders = reminders,
       assert(
         dueDate == null || dueDatetime == null,
         'Cannot have both dueDate and dueDatetime',
       );

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

      return DateTime.parse(processedDateStr).toUtc();
    } catch (e) {
      // Fallback: try parsing as-is
      try {
        return DateTime.parse(dateStr).toUtc();
      } catch (e2) {
        return null;
      }
    }
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    LoggingService.logger.fine('Task.fromJson: Processing task JSON: $json');
    try {
      LoggingService.logger.fine('Task.fromJson: id = ${json['id']}');
      LoggingService.logger.fine(
        'Task.fromJson: description = ${json['description']}',
      );
      LoggingService.logger.fine(
        'Task.fromJson: project_id = ${json['project_id']}',
      );
      LoggingService.logger.fine(
        'Task.fromJson: due_date = ${json['due_date']}',
      );
      LoggingService.logger.fine(
        'Task.fromJson: due_datetime = ${json['due_datetime']}',
      );
      LoggingService.logger.fine(
        'Task.fromJson: start_datetime = ${json['start_datetime']}',
      );
      LoggingService.logger.fine(
        'Task.fromJson: end_datetime = ${json['end_datetime']}',
      );
      LoggingService.logger.fine('Task.fromJson: labels = ${json['labels']}');
      LoggingService.logger.fine('Task.fromJson: order = ${json['order']}');
      LoggingService.logger.fine(
        'Task.fromJson: completed_at = ${json['completed_at']}',
      );
      LoggingService.logger.fine(
        'Task.fromJson: reminders = ${json['reminders']}',
      );
      LoggingService.logger.fine(
        'Task.fromJson: recurrence = ${json['recurrence']}',
      );

      return Task(
        id: json['id'],
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
      );
    } catch (e) {
      LoggingService.logger.severe(
        'Task.fromJson: Error processing task JSON (id: ${json['id']}, description: "${json['description']}"): $e. Raw JSON: $json',
      );
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'project_id': projectId,
      'due_date': dueDate?.toUtc().toIso8601String(),
      'due_datetime': dueDatetime?.toUtc().toIso8601String(),
      'start_datetime': startDatetime?.toUtc().toIso8601String(),
      'end_datetime': endDatetime?.toUtc().toIso8601String(),
      'labels': labels,
      'order': order,
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'reminders': reminders.map((e) => e.toUtc().toIso8601String()).toList(),
      'recurrence': recurrence,
    };
  }

  Task copyWith({
    int? id,
    String? description,
    int? projectId,
    ValueWrapper<DateTime?>? dueDate,
    ValueWrapper<DateTime?>? dueDatetime,
    ValueWrapper<DateTime?>? startDatetime,
    ValueWrapper<DateTime?>? endDatetime,
    List<String>? labels,
    int? order,
    ValueWrapper<DateTime?>? completedAt,
    List<DateTime>? reminders,
    String? recurrence,
  }) {
    return Task(
      id: id ?? this.id,
      description: description ?? this.description,
      projectId: projectId ?? this.projectId,
      dueDate: dueDate != null ? dueDate.value : this.dueDate,
      dueDatetime: dueDatetime != null ? dueDatetime.value : this.dueDatetime,
      startDatetime: startDatetime != null
          ? startDatetime.value
          : this.startDatetime,
      endDatetime: endDatetime != null ? endDatetime.value : this.endDatetime,
      labels: labels ?? this.labels,
      order: order ?? this.order,
      completedAt: completedAt != null ? completedAt.value : this.completedAt,
      reminders: reminders ?? this.reminders,
      recurrence: recurrence ?? this.recurrence,
    );
  }
}
