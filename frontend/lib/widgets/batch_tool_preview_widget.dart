import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../models/project.dart';
import '../models/ws_message_type.dart';
import 'tool_preview_widget.dart';

/// State for a single tool in the batch
class BatchToolState {
  final PendingToolCall toolCall;
  ToolPreviewStatus status;
  Map<String, dynamic> arguments;

  BatchToolState({
    required this.toolCall,
    this.status = ToolPreviewStatus.pending,
    Map<String, dynamic>? arguments,
  }) : arguments = arguments ?? Map.from(toolCall.arguments);
}

/// Widget that shows multiple tool actions for batch confirmation
class BatchToolPreviewWidget extends StatefulWidget {
  final List<PendingToolCall> toolCalls;
  final List<Project> projects;
  final void Function(List<ToolStatus>) onBatchConfirm;
  final void Function(List<ToolStatus>, String) onSendWithMessage;
  final String? duration;

  const BatchToolPreviewWidget({
    super.key,
    required this.toolCalls,
    required this.projects,
    required this.onBatchConfirm,
    required this.onSendWithMessage,
    this.duration,
  });

  @override
  State<BatchToolPreviewWidget> createState() => _BatchToolPreviewWidgetState();
}

class _BatchToolPreviewWidgetState extends State<BatchToolPreviewWidget> {
  late List<BatchToolState> _toolStates;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _toolStates = widget.toolCalls
        .map((tc) => BatchToolState(toolCall: tc))
        .toList();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _confirmTool(int index, Map<String, dynamic> args) {
    setState(() {
      _toolStates[index].status = ToolPreviewStatus.confirmed;
      _toolStates[index].arguments = args;
    });
  }

  void _rejectTool(int index) {
    setState(() {
      _toolStates[index].status = ToolPreviewStatus.cancelled;
    });
  }

  List<ToolStatus> _buildStatuses() {
    return _toolStates.map((state) {
      return ToolStatus(
        toolCallId: state.toolCall.toolCallId,
        status: state.status == ToolPreviewStatus.confirmed ? 'confirmed' : 'rejected',
        arguments: state.status == ToolPreviewStatus.confirmed ? state.arguments : null,
      );
    }).toList();
  }

  bool get _allActedOn => _toolStates.every((s) => s.status != ToolPreviewStatus.pending);

  void _submitBatch() {
    // Auto-reject any pending tools
    for (var state in _toolStates) {
      if (state.status == ToolPreviewStatus.pending) {
        state.status = ToolPreviewStatus.cancelled;
      }
    }

    final message = _messageController.text.trim();
    final statuses = _buildStatuses();

    if (message.isNotEmpty) {
      widget.onSendWithMessage(statuses, message);
    } else {
      widget.onBatchConfirm(statuses);
    }
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
          // Header
          Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.stack(),
                color: colors.primary,
                size: Sizes.iconMd,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                '${widget.toolCalls.length} Actions',
                style: theme.textTheme.titleMedium?.copyWith(color: colors.primary),
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
            ],
          ),
          const SizedBox(height: Spacing.md),

          // Tool previews
          ...List.generate(_toolStates.length, (index) {
            final state = _toolStates[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index < _toolStates.length - 1 ? Spacing.sm : 0),
              child: _SingleToolPreview(
                state: state,
                projects: widget.projects,
                onConfirm: (args) => _confirmTool(index, args),
                onReject: () => _rejectTool(index),
              ),
            );
          }),

          const SizedBox(height: Spacing.md),

          // Message input (optional)
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Add a message (optional)',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: Spacing.md),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!_allActedOn)
                TextButton(
                  onPressed: () {
                    // Reject all pending
                    for (var state in _toolStates) {
                      if (state.status == ToolPreviewStatus.pending) {
                        state.status = ToolPreviewStatus.cancelled;
                      }
                    }
                    setState(() {});
                  },
                  child: const Text('Reject All Pending'),
                ),
              const SizedBox(width: Spacing.sm),
              FilledButton(
                onPressed: _submitBatch,
                child: Text(_messageController.text.trim().isNotEmpty
                    ? 'Send'
                    : _allActedOn
                        ? 'Continue'
                        : 'Submit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Single tool preview within the batch
class _SingleToolPreview extends StatefulWidget {
  final BatchToolState state;
  final List<Project> projects;
  final void Function(Map<String, dynamic>) onConfirm;
  final VoidCallback onReject;

  const _SingleToolPreview({
    required this.state,
    required this.projects,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  State<_SingleToolPreview> createState() => _SingleToolPreviewState();
}

class _SingleToolPreviewState extends State<_SingleToolPreview> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (icon, title, color) = _getToolInfo(colors);
    final isPending = widget.state.status == ToolPreviewStatus.pending;
    final displayColor = isPending ? color : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.state.status == ToolPreviewStatus.confirmed
              ? colors.primary.withValues(alpha: 0.5)
              : widget.state.status == ToolPreviewStatus.cancelled
                  ? colors.error.withValues(alpha: 0.5)
                  : colors.outline.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(Radii.md),
        color: widget.state.status == ToolPreviewStatus.confirmed
            ? colors.primary.withValues(alpha: 0.05)
            : widget.state.status == ToolPreviewStatus.cancelled
                ? colors.error.withValues(alpha: 0.05)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              PhosphorIcon(icon, color: displayColor, size: Sizes.iconSm),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: displayColor),
                ),
              ),
              if (widget.state.status == ToolPreviewStatus.confirmed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.xs, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(Radii.xs),
                  ),
                  child: Text(
                    'Confirmed',
                    style: theme.textTheme.labelSmall?.copyWith(color: colors.onTertiaryContainer),
                  ),
                ),
              if (widget.state.status == ToolPreviewStatus.cancelled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.xs, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(Radii.xs),
                  ),
                  child: Text(
                    'Rejected',
                    style: theme.textTheme.labelSmall?.copyWith(color: colors.onErrorContainer),
                  ),
                ),
            ],
          ),

          // Preview content
          const SizedBox(height: Spacing.sm),
          _buildPreviewContent(context),

          // Actions (only if pending)
          if (isPending) ...[
            const SizedBox(height: Spacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onReject,
                  child: const Text('Reject'),
                ),
                const SizedBox(width: Spacing.xs),
                FilledButton(
                  onPressed: () => widget.onConfirm(widget.state.arguments),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.state.toolCall.name.contains('delete')
                        ? colors.error
                        : widget.state.toolCall.name.contains('complete')
                            ? colors.tertiary
                            : colors.primary,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    final theme = Theme.of(context);
    final args = widget.state.arguments;

    // Show key info based on tool type
    switch (widget.state.toolCall.name) {
      case 'create_task':
      case 'update_task':
        final desc = args['description'] as String? ?? '';
        return Text(desc, style: theme.textTheme.bodyMedium);
      case 'delete_task':
      case 'complete_task':
        final desc = args['description'] as String? ?? 'Task #${args['task_id']}';
        return Text(desc, style: theme.textTheme.bodyMedium);
      case 'create_project':
      case 'update_project':
        final name = args['name'] as String? ?? '';
        return Text(name, style: theme.textTheme.bodyMedium);
      case 'delete_project':
        final name = args['name'] as String? ?? 'Project #${args['project_id']}';
        return Text(name, style: theme.textTheme.bodyMedium);
      default:
        return Text(args.toString(), style: theme.textTheme.bodySmall);
    }
  }

  (PhosphorIconData, String, Color) _getToolInfo(ColorScheme colors) {
    switch (widget.state.toolCall.name) {
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
}
