import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/ws_message_type.dart';
import 'tool_preview_widget.dart';

/// Widget that shows multiple tool actions with streaming confirmation
class BatchToolPreviewWidget extends StatefulWidget {
  final List<PendingToolCall> toolCalls;
  final List<Project> projects;
  final void Function(String toolCallId, Map<String, dynamic> args) onConfirmSingle;
  final String? duration;

  const BatchToolPreviewWidget({
    super.key,
    required this.toolCalls,
    required this.projects,
    required this.onConfirmSingle,
    this.duration,
  });

  @override
  State<BatchToolPreviewWidget> createState() => _BatchToolPreviewWidgetState();
}

class _BatchToolPreviewWidgetState extends State<BatchToolPreviewWidget> {
  final Map<String, ToolPreviewStatus> _statuses = {};
  final Map<String, Map<String, dynamic>> _editedArgs = {};

  @override
  void initState() {
    super.initState();
    _initializeToolStates();
  }

  @override
  void didUpdateWidget(BatchToolPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize if toolCalls changed
    if (oldWidget.toolCalls != widget.toolCalls) {
      _initializeToolStates();
    }
  }

  void _initializeToolStates() {
    _statuses.clear();
    _editedArgs.clear();
    for (final tc in widget.toolCalls) {
      _statuses[tc.toolCallId] = ToolPreviewStatus.pending;
      _editedArgs[tc.toolCallId] = Map.from(tc.arguments);
    }
  }

  void _confirmTool(String toolCallId, Map<String, dynamic> args) {
    // Update local state
    setState(() {
      _statuses[toolCallId] = ToolPreviewStatus.confirmed;
      _editedArgs[toolCallId] = args;
    });

    // Immediately send confirmation to backend
    widget.onConfirmSingle(toolCallId, args);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: widget.toolCalls.map((tc) {
        return ToolPreviewWidget(
          key: ValueKey(tc.toolCallId),
          toolName: tc.name,
          arguments: _editedArgs[tc.toolCallId]!,
          projects: widget.projects,
          status: _statuses[tc.toolCallId]!,
          onConfirm: (args) => _confirmTool(tc.toolCallId, args),
          onReject: () {}, // Reject is implicit when user sends a new message
        );
      }).toList(),
    );
  }
}
