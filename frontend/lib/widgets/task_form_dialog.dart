import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dimaist/models/project.dart';
import 'package:dimaist/models/task.dart';
import 'package:dimaist/services/app_database.dart';
import 'package:dimaist/config/design_tokens.dart';
import 'label_selector.dart';
import 'recurrence_picker.dart';

class TaskFormDialog extends ConsumerStatefulWidget {
  final Task? task;
  final List<Project> projects;
  final Project? selectedProject;
  final DateTime? defaultDueDate;
  final Function(Task) onSave;
  final Function(int)? onDelete;
  final String title;
  final String submitButtonText;

  const TaskFormDialog({
    super.key,
    this.task,
    required this.projects,
    this.selectedProject,
    this.defaultDueDate,
    required this.onSave,
    this.onDelete,
    required this.title,
    required this.submitButtonText,
  });

  @override
  TaskFormDialogState createState() => TaskFormDialogState();
}

class TaskFormDialogState extends ConsumerState<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  String? _recurrence;
  List<String> _selectedLabels = [];
  int? _selectedProjectId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _selectedStartDate;
  TimeOfDay? _selectedStartTime;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;
  final AppDatabase _db = AppDatabase();
  List<String> _selectedReminders = [];

  final List<String> _reminderOptions = [
    '5 minutes',
    '30 minutes',
    '1 hour',
    '12 hours',
    '1 day',
    '1 week',
  ];

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _recurrence = task?.recurrence;
    _selectedLabels = List<String>.from(task?.labels ?? []);
    _selectedProjectId = task?.projectId ?? widget.selectedProject?.id;
    if (task != null) {
      if (task.dueDatetime != null) {
        _selectedDate = task.dueDatetime;
        _selectedTime = TimeOfDay.fromDateTime(task.dueDatetime!);
      } else if (task.dueDate != null) {
        _selectedDate = task.dueDate;
      }
      if (task.startDatetime != null) {
        _selectedStartDate = task.startDatetime;
        _selectedStartTime = TimeOfDay.fromDateTime(task.startDatetime!);
      }
      if (task.endDatetime != null) {
        _selectedEndDate = task.endDatetime;
        _selectedEndTime = TimeOfDay.fromDateTime(task.endDatetime!);
      }
      if (task.reminders.isNotEmpty) {
        _selectedReminders = task.reminders
            .map(
              (e) => _reminderStringFromDateTime(
                e,
                task.dueDatetime ?? task.dueDate!,
              ),
            )
            .toList();
      }
    } else if (widget.defaultDueDate != null) {
      _selectedDate = widget.defaultDueDate;
    }
  }

  String _reminderStringFromDateTime(DateTime reminder, DateTime dueDate) {
    final difference = dueDate.difference(reminder);
    if (difference.inDays >= 7) {
      return '${difference.inDays ~/ 7} week';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour';
    } else if (difference.inMinutes >= 30) {
      return '30 minutes';
    } else {
      return '5 minutes';
    }
  }

  bool _hasScheduleOrRecurrence() {
    return _selectedStartDate != null ||
        _selectedEndDate != null ||
        (_recurrence != null && _recurrence!.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.title),
          if (widget.task != null && widget.onDelete != null)
            TextButton.icon(
              onPressed: _confirmDelete,
              style: TextButton.styleFrom(
                foregroundColor: colors.error,
              ),
              icon: const Icon(Icons.delete_outline, size: Sizes.iconSm),
              label: const Text('Delete'),
            ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description
              TextFormField(
                autofocus: true,
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),

              const SizedBox(height: Spacing.lg),

              // Project + Due Date Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project dropdown
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedProjectId,
                      decoration: const InputDecoration(
                        labelText: 'Project',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: Spacing.md,
                          vertical: Spacing.sm,
                        ),
                      ),
                      items: widget.projects.map((project) {
                        return DropdownMenuItem<int>(
                          value: project.id,
                          child: Text(
                            project.name,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProjectId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(width: Spacing.md),

                  // Due date picker
                  Expanded(child: _buildDueDatePicker(theme, colors)),
                ],
              ),

              const SizedBox(height: Spacing.lg),

              // Labels
              LabelSelector(
                selectedLabels: _selectedLabels,
                onChanged: (labels) {
                  setState(() {
                    _selectedLabels = labels;
                  });
                },
              ),

              // Reminders (only when due date is set)
              if (_selectedDate != null) ...[
                const SizedBox(height: Spacing.lg),
                _buildRemindersSection(theme, colors),
              ],

              const SizedBox(height: Spacing.md),

              // More Options (collapsed by default)
              _buildMoreOptions(theme, colors),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _handleSave,
          child: Text(widget.submitButtonText),
        ),
      ],
    );
  }

  Widget _buildDueDatePicker(ThemeData theme, ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          // Date button
          Expanded(
            child: InkWell(
              onTap: _showDatePickerDialog,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(Radii.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: Sizes.iconSm,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        _selectedDate != null
                            ? DateFormat('MMM d').format(_selectedDate!)
                            : 'Date',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _selectedDate != null
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Divider
          Container(
            width: 1,
            height: 24,
            color: colors.outline,
          ),

          // Time button
          InkWell(
            onTap: _showTimePickerDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.md,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: Sizes.iconSm,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    _selectedTime != null
                        ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                        : '—',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _selectedTime != null
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Clear button
          if (_selectedDate != null)
            IconButton(
              icon: Icon(Icons.clear, size: Sizes.iconSm),
              onPressed: _clearDateTime,
              padding: const EdgeInsets.all(Spacing.sm),
              constraints: const BoxConstraints(),
              tooltip: 'Clear date',
            ),
        ],
      ),
    );
  }

  Widget _buildRemindersSection(ThemeData theme, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reminders',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: _reminderOptions.map((reminder) {
            return FilterChip(
              label: Text(reminder),
              selected: _selectedReminders.contains(reminder),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedReminders.add(reminder);
                  } else {
                    _selectedReminders.remove(reminder);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMoreOptions(ThemeData theme, ColorScheme colors) {
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          'More options',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: Spacing.sm),
        initiallyExpanded: _hasScheduleOrRecurrence(),
        children: [
          // Recurrence picker
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recurrence',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              RecurrencePicker(
                initialValue: _recurrence,
                onChanged: (value) {
                  setState(() => _recurrence = value);
                },
              ),
            ],
          ),

          const SizedBox(height: Spacing.lg),

          // Schedule section
          _buildScheduleSection(theme, colors),
        ],
      ),
    );
  }

  Widget _buildScheduleSection(ThemeData theme, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Schedule',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            if (_selectedStartDate != null || _selectedEndDate != null)
              IconButton(
                icon: Icon(Icons.clear, size: Sizes.iconSm),
                onPressed: _clearSchedule,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Clear schedule',
              ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            // Start
            Expanded(
              child: _DateTimeField(
                label: 'Start',
                date: _selectedStartDate,
                time: _selectedStartTime,
                onDateTap: () => _pickScheduleDate(isStart: true),
                onTimeTap: () => _pickScheduleTime(isStart: true),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
              child: Icon(
                Icons.arrow_forward,
                size: Sizes.iconSm,
                color: colors.onSurfaceVariant,
              ),
            ),

            // End
            Expanded(
              child: _DateTimeField(
                label: 'End',
                date: _selectedEndDate,
                time: _selectedEndTime,
                onDateTap: () => _pickScheduleDate(isStart: false),
                onTimeTap: () => _pickScheduleTime(isStart: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Date/Time Picker Methods

  Future<void> _showDatePickerDialog() async {
    final now = DateTime.now();
    final defaultFirstDate = now.subtract(const Duration(days: 365));
    final defaultLastDate = now.add(const Duration(days: 365));

    final firstDate = _selectedDate != null && _selectedDate!.isBefore(defaultFirstDate)
        ? _selectedDate!
        : defaultFirstDate;

    final lastDate = _selectedDate != null && _selectedDate!.isAfter(defaultLastDate)
        ? _selectedDate!.add(const Duration(days: 365))
        : defaultLastDate;

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _showTimePickerDialog() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
        _selectedDate ??= DateTime.now();
      });
    }
  }

  void _clearDateTime() {
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
      _selectedReminders.clear();
    });
  }

  void _clearSchedule() {
    setState(() {
      _selectedStartDate = null;
      _selectedStartTime = null;
      _selectedEndDate = null;
      _selectedEndTime = null;
    });
  }

  Future<void> _pickScheduleDate({required bool isStart}) async {
    final currentDate = isStart ? _selectedStartDate : _selectedEndDate;
    final date = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        if (isStart) {
          _selectedStartDate = date;
        } else {
          _selectedEndDate = date;
        }
      });
    }
  }

  Future<void> _pickScheduleTime({required bool isStart}) async {
    final currentTime = isStart ? _selectedStartTime : _selectedEndTime;
    final time = await showTimePicker(
      context: context,
      initialTime: currentTime ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _selectedStartTime = time;
          _selectedStartDate ??= DateTime.now();
        } else {
          _selectedEndTime = time;
          _selectedEndDate ??= DateTime.now();
        }
      });
    }
  }

  // Delete Handler

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.onDelete!(widget.task!.id!);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // Save Handler

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final errorColor = Theme.of(context).colorScheme.error;
      try {
        DateTime? dueDate;
        DateTime? dueDatetime;
        if (_selectedDate != null) {
          if (_selectedTime != null) {
            dueDatetime = DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
              _selectedTime!.hour,
              _selectedTime!.minute,
            );
          } else {
            dueDate = DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
              23,
              59,
            );
          }
        }

        DateTime? startDatetime;
        DateTime? endDatetime;
        if (_selectedStartDate != null && _selectedStartTime != null) {
          startDatetime = DateTime(
            _selectedStartDate!.year,
            _selectedStartDate!.month,
            _selectedStartDate!.day,
            _selectedStartTime!.hour,
            _selectedStartTime!.minute,
          );
        }
        if (_selectedEndDate != null && _selectedEndTime != null) {
          endDatetime = DateTime(
            _selectedEndDate!.year,
            _selectedEndDate!.month,
            _selectedEndDate!.day,
            _selectedEndTime!.hour,
            _selectedEndTime!.minute,
          );
        }

        final tasksForProject = await _db.getTasksByProject(
          _selectedProjectId!,
        );
        final newOrder =
            (tasksForProject.isNotEmpty
                ? tasksForProject
                      .map((t) => t.order)
                      .reduce((a, b) => a > b ? a : b)
                : 0) +
            1;

        List<DateTime> reminders = [];
        if (dueDatetime != null) {
          for (final reminderString in _selectedReminders) {
            reminders.add(
              dueDatetime.subtract(_getDuration(reminderString)),
            );
          }
        } else if (dueDate != null) {
          for (final reminderString in _selectedReminders) {
            reminders.add(
              dueDate.subtract(_getDuration(reminderString)),
            );
          }
        }

        final task = Task(
          id: widget.task?.id,
          description: _descriptionController.text,
          projectId: _selectedProjectId!,
          dueDate: dueDate,
          dueDatetime: dueDatetime,
          startDatetime: startDatetime,
          endDatetime: endDatetime,
          labels: _selectedLabels,
          order: widget.task?.order ?? newOrder,
          completedAt: widget.task?.completedAt,
          reminders: reminders,
          recurrence: _recurrence ?? '',
        );

        await widget.onSave(task);
        navigator.pop();
      } catch (e) {
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Duration _getDuration(String reminderString) {
    final parts = reminderString.split(' ');
    final value = int.parse(parts[0]);
    final unit = parts[1];

    switch (unit) {
      case 'minutes':
        return Duration(minutes: value);
      case 'hour':
        return Duration(hours: value);
      case 'hours':
        return Duration(hours: value);
      case 'day':
        return Duration(days: value);
      case 'week':
        return Duration(days: value * 7);
      default:
        return Duration.zero;
    }
  }
}

/// Compact date+time field for schedule section
class _DateTimeField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;

  const _DateTimeField({
    required this.label,
    required this.date,
    required this.time,
    required this.onDateTap,
    required this.onTimeTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Row(
          children: [
            InkWell(
              onTap: onDateTap,
              child: Text(
                date != null
                    ? DateFormat('M/d').format(date!)
                    : 'Date',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: date != null ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              ' @ ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            InkWell(
              onTap: onTimeTap,
              child: Text(
                time != null
                    ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
                    : 'Time',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: time != null ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
