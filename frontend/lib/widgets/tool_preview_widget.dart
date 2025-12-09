import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../utils/color_utils.dart';
import 'task_form_dialog.dart';
import 'task_widget.dart';

enum ToolPreviewStatus { pending, confirmed, cancelled }

/// Widget that shows a preview of a tool action and allows confirmation/rejection
class ToolPreviewWidget extends StatefulWidget {
  final String toolName;
  final Map<String, dynamic> arguments;
  final void Function(Map<String, dynamic>) onConfirm;
  final VoidCallback onReject;
  final List<Project> projects;
  final ToolPreviewStatus status;
  final String? duration;

  const ToolPreviewWidget({
    super.key,
    required this.toolName,
    required this.arguments,
    required this.onConfirm,
    required this.onReject,
    required this.projects,
    this.status = ToolPreviewStatus.pending,
    this.duration,
  });

  @override
  State<ToolPreviewWidget> createState() => _ToolPreviewWidgetState();
}

class _ToolPreviewWidgetState extends State<ToolPreviewWidget> {
  late Map<String, dynamic> _editedArguments;

  @override
  void initState() {
    super.initState();
    _editedArguments = Map.from(widget.arguments);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _buildPreview(context)),
          if (widget.status == ToolPreviewStatus.pending)
            _buildCompactActions(colors),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    // Check for backend error first
    final backendError = _editedArguments['_error'] as String?;
    if (backendError != null) {
      return _buildErrorPreview(context, backendError);
    }

    try {
      switch (widget.toolName) {
        case 'create_task':
        case 'update_task':
          return _buildTaskPreview(context, editable: true);
        case 'delete_task':
          return _buildTaskPreview(context, editable: false, isDelete: true);
        case 'complete_task':
          return _buildTaskPreview(context, editable: false, isComplete: true);
        case 'create_project':
        case 'update_project':
          return _buildProjectPreview(context, editable: true);
        case 'delete_project':
          return _buildProjectPreview(context, editable: false, isDelete: true);
        default:
          return _buildGenericPreview(context);
      }
    } catch (e) {
      return _buildErrorPreview(context, e.toString());
    }
  }

  Widget _buildErrorPreview(BuildContext context, String error) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        error,
        style: theme.textTheme.bodyMedium?.copyWith(color: colors.onErrorContainer),
      ),
    );
  }

  Task _buildTaskFromArguments() {
    return Task.fromJson({
      'project_id': widget.projects.firstOrNull?.id ?? 0,
      'order': 0,
      ..._editedArguments,
    });
  }

  Widget _buildTaskPreview(
    BuildContext context, {
    required bool editable,
    bool isDelete = false,
    bool isComplete = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final task = _buildTaskFromArguments();

    // Border color based on action type
    final borderColor = isDelete
        ? colors.error
        : isComplete
            ? colors.tertiary
            : null;

    // Find project for task
    final project = widget.projects.where((p) => p.id == task.projectId).firstOrNull;

    Widget taskWidget = TaskWidget(
      task: task,
      onToggleComplete: (_) {}, // No-op for preview
      onEdit: editable && widget.status == ToolPreviewStatus.pending
          ? (_) => _openTaskEditDialog(context)
          : (_) {}, // No-op if not editable
      showCheckbox: false,
      project: project,
    );

    // Wrap with border for delete/complete states
    if (borderColor != null) {
      taskWidget = Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(Radii.md + 2),
        ),
        child: taskWidget,
      );
    }

    return taskWidget;
  }

  Widget _buildProjectPreview(
    BuildContext context, {
    required bool editable,
    bool isDelete = false,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final name = _editedArguments['name'] as String? ?? '';
    final color = _editedArguments['color'] as String? ?? 'gray';

    final borderColor = isDelete ? colors.error : colors.outline;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      child: Row(
        children: [
          Container(
            width: Sizes.avatarSm,
            height: Sizes.avatarSm,
            decoration: BoxDecoration(
              color: getColor(color),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(name, style: theme.textTheme.bodyMedium),
          ),
          if (editable && widget.status == ToolPreviewStatus.pending)
            IconButton(
              onPressed: () => _openProjectEditDialog(context),
              icon: PhosphorIcon(PhosphorIcons.pencilSimple(), size: Sizes.iconSm),
              tooltip: 'Edit',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildGenericPreview(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        _editedArguments.toString(),
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  Widget _buildCompactActions(ColorScheme colors) {
    final (icon, tooltip, color) = _getActionInfo(colors);

    return IconButton(
      onPressed: () => widget.onConfirm(_editedArguments),
      icon: PhosphorIcon(icon, size: Sizes.iconMd),
      tooltip: tooltip,
      color: color,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
      ),
    );
  }

  (PhosphorIconData, String, Color) _getActionInfo(ColorScheme colors) {
    return switch (widget.toolName) {
      'create_task' || 'create_project' => (PhosphorIcons.plus(), 'Create', colors.primary),
      'update_task' || 'update_project' => (PhosphorIcons.check(), 'Update', colors.primary),
      'delete_task' || 'delete_project' => (PhosphorIcons.trash(), 'Delete', colors.error),
      'complete_task' => (PhosphorIcons.check(), 'Complete', colors.tertiary),
      _ => (PhosphorIcons.check(), 'Confirm', colors.primary),
    };
  }

  void _openTaskEditDialog(BuildContext context) {
    final task = _buildTaskFromArguments();

    showDialog(
      context: context,
      builder: (context) => TaskFormDialog(
        task: task,
        projects: widget.projects,
        onSave: (updatedTask) {
          setState(() {
            _editedArguments['description'] = updatedTask.description;
            _editedArguments['project_id'] = updatedTask.projectId;

            // Handle due date using unified getter
            if (updatedTask.due != null) {
              _editedArguments['due_date'] = updatedTask.due!.toIso8601String();
            } else {
              _editedArguments.remove('due_date');
            }

            if (updatedTask.labels.isNotEmpty) {
              _editedArguments['labels'] = updatedTask.labels;
            } else {
              _editedArguments.remove('labels');
            }

            if (updatedTask.recurrence != null && updatedTask.recurrence!.isNotEmpty) {
              _editedArguments['recurrence'] = updatedTask.recurrence;
            } else {
              _editedArguments.remove('recurrence');
            }
          });
        },
        title: 'Edit Task',
        submitButtonText: 'Save',
      ),
    );
  }

  void _openProjectEditDialog(BuildContext context) async {
    final nameController = TextEditingController(
      text: _editedArguments['name'] as String? ?? '',
    );
    String selectedColor = _editedArguments['color'] as String? ?? 'gray';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: Spacing.md),
              DropdownButtonFormField<String>(
                initialValue: selectedColor,
                decoration: const InputDecoration(labelText: 'Color'),
                items: ['gray', 'red', 'orange', 'yellow', 'green', 'blue', 'purple', 'pink']
                    .map((c) => DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: getColor(c),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          Text(c),
                        ],
                      ),
                    ))
                    .toList(),
                onChanged: (value) => setDialogState(() => selectedColor = value ?? 'gray'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'name': nameController.text,
                'color': selectedColor,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _editedArguments['name'] = result['name'];
        _editedArguments['color'] = result['color'];
      });
    }
  }
}
