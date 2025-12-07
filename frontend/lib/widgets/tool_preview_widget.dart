import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../models/project.dart';
import '../models/task.dart';
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(theme, colors),
          const SizedBox(height: Spacing.md),
          _buildPreview(context),
          if (widget.status == ToolPreviewStatus.pending) ...[
            const SizedBox(height: Spacing.md),
            _buildActions(colors),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colors) {
    final (icon, title, color) = _getToolInfo(colors);
    final isCompleted = widget.status != ToolPreviewStatus.pending;
    final displayColor = isCompleted ? colors.onSurfaceVariant : color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PhosphorIcon(icon, color: displayColor, size: Sizes.iconMd),
        const SizedBox(width: Spacing.sm),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(color: displayColor),
        ),
        if (widget.duration != null) ...[
          const SizedBox(width: Spacing.xs),
          Text(
            widget.duration!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
        if (widget.status == ToolPreviewStatus.confirmed) ...[
          const SizedBox(width: Spacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
            decoration: BoxDecoration(
              color: colors.tertiaryContainer,
              borderRadius: BorderRadius.circular(Radii.xs),
            ),
            child: Text(
              'Done',
              style: theme.textTheme.labelSmall?.copyWith(color: colors.onTertiaryContainer),
            ),
          ),
        ],
        if (widget.status == ToolPreviewStatus.cancelled) ...[
          const SizedBox(width: Spacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(Radii.xs),
            ),
            child: Text(
              'Cancelled',
              style: theme.textTheme.labelSmall?.copyWith(color: colors.onErrorContainer),
            ),
          ),
        ],
      ],
    );
  }

  (PhosphorIconData, String, Color) _getToolInfo(ColorScheme colors) {
    switch (widget.toolName) {
      case 'create_task':
        return (PhosphorIcons.listPlus(), 'Create Task', colors.primary);
      case 'update_task':
        return (PhosphorIcons.pencilSimple(), 'Update Task', colors.secondary);
      case 'delete_task':
        return (PhosphorIcons.trash(), 'Delete Task', colors.error);
      case 'complete_task':
        return (PhosphorIcons.checkCircle(), 'Complete Task', colors.tertiary);
      case 'create_project':
        return (PhosphorIcons.folderPlus(), 'Create Project', colors.primary);
      case 'update_project':
        return (PhosphorIcons.pencilSimple(), 'Update Project', colors.secondary);
      case 'delete_project':
        return (PhosphorIcons.folderMinus(), 'Delete Project', colors.error);
      default:
        return (PhosphorIcons.question(), 'Unknown Action', colors.onSurface);
    }
  }

  Widget _buildPreview(BuildContext context) {
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
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: Sizes.avatarMd,
                height: Sizes.avatarMd,
                decoration: BoxDecoration(
                  color: _parseColor(color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(name, style: theme.textTheme.bodyLarge),
              ),
            ],
          ),
          if (editable && widget.status == ToolPreviewStatus.pending) ...[
            const SizedBox(height: Spacing.sm),
            OutlinedButton.icon(
              onPressed: () => _openProjectEditDialog(context),
              icon: PhosphorIcon(PhosphorIcons.pencilSimple(), size: Sizes.iconSm),
              label: const Text('Edit'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenericPreview(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Text(
        _editedArguments.toString(),
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  Widget _buildActions(ColorScheme colors) {
    // Don't show actions when read-only
    if (widget.status != ToolPreviewStatus.pending) {
      return const SizedBox.shrink();
    }

    final isDelete = widget.toolName.contains('delete');
    final isComplete = widget.toolName.contains('complete');

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: widget.onReject,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: Spacing.sm),
        FilledButton(
          onPressed: () => widget.onConfirm(_editedArguments),
          style: FilledButton.styleFrom(
            backgroundColor: isDelete
                ? colors.error
                : isComplete
                    ? colors.tertiary
                    : colors.primary,
          ),
          child: Text(
            isDelete
                ? 'Delete'
                : isComplete
                    ? 'Complete'
                    : 'Confirm',
          ),
        ),
      ],
    );
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
                              color: _parseColor(c),
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

  Color _parseColor(String colorName) {
    const colorMap = {
      'red': Colors.red,
      'pink': Colors.pink,
      'purple': Colors.purple,
      'blue': Colors.blue,
      'cyan': Colors.cyan,
      'teal': Colors.teal,
      'green': Colors.green,
      'lime': Colors.lime,
      'yellow': Colors.yellow,
      'amber': Colors.amber,
      'orange': Colors.orange,
      'brown': Colors.brown,
      'gray': Colors.grey,
      'grey': Colors.grey,
    };
    return colorMap[colorName.toLowerCase()] ?? Colors.grey;
  }
}
