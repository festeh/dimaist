import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:dimaist/models/project.dart';
import 'package:dimaist/models/task.dart';
import 'package:dimaist/services/app_database.dart';
import 'package:dimaist/config/design_tokens.dart';
import 'datetime_field.dart';
import 'label_selector.dart';
import 'recurrence_picker.dart';
import 'reminder_picker.dart';

class TaskFormDialog extends ConsumerStatefulWidget {
  final Task? task;
  final List<Project> projects;
  final Project? selectedProject;
  final DateTime? defaultDueDate;
  /// Returns a warning message if calendar sync failed, null otherwise.
  final Future<String?> Function(Task) onSave;
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
  late TextEditingController _titleController;
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

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(
      text: task?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _recurrence = task?.recurrence;
    _selectedLabels = List<String>.from(task?.labels ?? []);
    _selectedProjectId = task?.projectId ?? widget.selectedProject?.id;
    if (task != null) {
      if (task.due != null) {
        _selectedDate = task.due;
        if (task.hasTime) {
          _selectedTime = TimeOfDay.fromDateTime(task.due!);
        }
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
            .map((e) => reminderDateTimeToString(e, task.due!))
            .toList();
      }
    } else if (widget.defaultDueDate != null) {
      _selectedDate = widget.defaultDueDate;
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
              icon: PhosphorIcon(PhosphorIcons.trash(), size: Sizes.iconSm),
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
              // Title
              Text(
                'Title',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              TextFormField(
                autofocus: true,
                controller: _titleController,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),

              const SizedBox(height: Spacing.lg),

              // Description
              Text(
                'Description',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              TextFormField(
                controller: _descriptionController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
              ),

              const SizedBox(height: Spacing.lg),

              // Project dropdown
              Text(
                'Project',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              IntrinsicWidth(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedProjectId,
                  decoration: const InputDecoration(
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

              const SizedBox(height: Spacing.lg),

              // Due date picker
              Text(
                'Due',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              _buildDueDatePicker(theme, colors),

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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date button
          InkWell(
              onTap: _showDatePickerDialog,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(Radii.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.calendar(),
                      size: Sizes.iconSm,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      _selectedDate != null
                          ? DateFormat('MMM d').format(_selectedDate!)
                          : 'Date',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _selectedDate != null
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
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
                  PhosphorIcon(
                    PhosphorIcons.clock(),
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
              icon: PhosphorIcon(PhosphorIcons.x(), size: Sizes.iconSm),
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
    return ReminderPicker(
      selectedReminders: _selectedReminders,
      onChanged: (reminders) => setState(() => _selectedReminders = reminders),
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
                icon: PhosphorIcon(PhosphorIcons.x(), size: Sizes.iconSm),
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
              child: DateTimeField(
                label: 'Start',
                date: _selectedStartDate,
                time: _selectedStartTime,
                onDateTap: () => _pickScheduleDate(isStart: true),
                onTimeTap: () => _pickScheduleTime(isStart: true),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
              child: PhosphorIcon(
                PhosphorIcons.arrowRight(),
                size: Sizes.iconSm,
                color: colors.onSurfaceVariant,
              ),
            ),

            // End
            Expanded(
              child: DateTimeField(
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
              dueDatetime.subtract(reminderStringToDuration(reminderString)),
            );
          }
        } else if (dueDate != null) {
          for (final reminderString in _selectedReminders) {
            reminders.add(
              dueDate.subtract(reminderStringToDuration(reminderString)),
            );
          }
        }

        final descriptionText = _descriptionController.text.trim();
        final task = Task(
          id: widget.task?.id,
          title: _titleController.text,
          description: descriptionText.isEmpty ? null : descriptionText,
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

        final warning = await widget.onSave(task);
        navigator.pop();

        // Show warning if calendar sync failed
        if (warning != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Warning: $warning'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
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
}
