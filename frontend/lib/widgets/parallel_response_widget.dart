import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../models/project.dart';
import '../providers/parallel_ai_provider.dart';
import 'batch_tool_preview_widget.dart';

/// Inline widget that displays parallel AI responses with arrow navigation
class ParallelResponseWidget extends ConsumerStatefulWidget {
  final Map<String, ModelResponse> responses;
  final List<Project> projects;
  final bool allComplete;
  final void Function(String targetId) onToolInteraction;
  final void Function(String targetId, String toolCallId, Map<String, dynamic> args)
      onToolConfirmSingle;
  final String? lockedToModel;  // When set, navigation is disabled

  const ParallelResponseWidget({
    super.key,
    required this.responses,
    required this.projects,
    required this.allComplete,
    required this.onToolInteraction,
    required this.onToolConfirmSingle,
    this.lockedToModel,
  });

  @override
  ConsumerState<ParallelResponseWidget> createState() =>
      _ParallelResponseWidgetState();
}

class _ParallelResponseWidgetState
    extends ConsumerState<ParallelResponseWidget> {
  int _currentIndex = 0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus on Linux for keyboard navigation
    if (Platform.isLinux) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Completed responses to display
  /// - Success/toolsPending shown immediately
  /// - Errors only shown after allComplete (prevents flickering from fast errors)
  /// - Sorted: success/toolsPending first (by duration), then errors (by duration)
  /// - When locked to a model, only show that model
  List<MapEntry<String, ModelResponse>> get _completedResponses {
    final result = widget.responses.entries
        .where((e) {
          // When locked, only show the locked model
          if (widget.lockedToModel != null && e.key != widget.lockedToModel) {
            return false;
          }
          // Always exclude pending
          if (e.value.status == ResponseStatus.pending) return false;
          // Hide errors until allComplete
          if (e.value.status == ResponseStatus.error && !widget.allComplete) return false;
          return true;
        })
        .toList()
      ..sort((a, b) {
        // Errors always come last
        final aIsError = a.value.status == ResponseStatus.error;
        final bIsError = b.value.status == ResponseStatus.error;
        if (aIsError != bIsError) {
          return aIsError ? 1 : -1; // Errors to the end
        }
        // Within same category, sort by duration (fastest first)
        return (a.value.duration ?? double.infinity)
            .compareTo(b.value.duration ?? double.infinity);
      });
    return result;
  }

  void _goLeft() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      ref.read(parallelAiProvider.notifier).setCurrentPage(_currentIndex);
    }
  }

  void _goRight() {
    if (_currentIndex < _completedResponses.length - 1) {
      setState(() {
        _currentIndex++;
      });
      ref.read(parallelAiProvider.notifier).setCurrentPage(_currentIndex);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _goLeft();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _goRight();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final completedResponses = _completedResponses;

    if (completedResponses.isEmpty) {
      return const SizedBox.shrink();
    }

    // Clamp index if responses changed
    if (_currentIndex >= completedResponses.length) {
      _currentIndex = completedResponses.length - 1;
    }

    final currentEntry = completedResponses[_currentIndex];
    final canGoLeft = _currentIndex > 0;
    final canGoRight = _currentIndex < completedResponses.length - 1;
    final totalCount = completedResponses.length;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: colors.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with arrows and model name
            _buildHeader(
              context,
              currentEntry.key,
              currentEntry.value,
              canGoLeft,
              canGoRight,
              _currentIndex + 1,
              totalCount,
              theme,
              colors,
            ),

            const Divider(height: 1),

            // Response content
            _buildResponseContent(
              context,
              currentEntry.key,
              currentEntry.value,
              theme,
              colors,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String targetId,
    ModelResponse response,
    bool canGoLeft,
    bool canGoRight,
    int currentNum,
    int totalNum,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final modelName = _getModelDisplayName(targetId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs, vertical: Spacing.xs),
      child: Row(
        children: [
          // Left arrow
          IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.caretLeft(),
              size: Sizes.iconMd,
            ),
            onPressed: canGoLeft ? _goLeft : null,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),

          // Model name and position
          Expanded(
            child: Text(
              '$modelName ($currentNum/$totalNum)',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Duration
          if (response.duration != null)
            Padding(
              padding: const EdgeInsets.only(right: Spacing.xs),
              child: Text(
                _formatDuration(response.duration!),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),

          // Right arrow
          IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.caretRight(),
              size: Sizes.iconMd,
            ),
            onPressed: canGoRight ? _goRight : null,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseContent(
    BuildContext context,
    String targetId,
    ModelResponse response,
    ThemeData theme,
    ColorScheme colors,
  ) {
    Widget content;

    switch (response.status) {
      case ResponseStatus.pending:
        content = Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                'Waiting for response...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
        break;

      case ResponseStatus.error:
        content = Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                PhosphorIcons.warning(),
                size: Sizes.iconMd,
                color: colors.error,
              ),
              const SizedBox(width: Spacing.sm),
              Flexible(
                child: Text(
                  response.error ?? 'Unknown error',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.error,
                  ),
                ),
              ),
            ],
          ),
        );
        break;

      case ResponseStatus.toolsPending:
        if (response.toolCalls == null || response.toolCalls!.isEmpty) {
          content = const Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Text('No tools'),
          );
        } else {
          content = Padding(
            padding: const EdgeInsets.all(Spacing.sm),
            child: BatchToolPreviewWidget(
              toolCalls: response.toolCalls!,
              projects: widget.projects,
              onConfirmSingle: (toolCallId, args) {
                widget.onToolConfirmSingle(targetId, toolCallId, args);
              },
            ),
          );
        }
        break;

      case ResponseStatus.success:
        content = Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: MarkdownBody(
            data: response.content ?? '',
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: theme.textTheme.bodyMedium,
              h1: theme.textTheme.headlineLarge,
              h2: theme.textTheme.headlineMedium,
              h3: theme.textTheme.headlineSmall,
              h4: theme.textTheme.titleLarge,
              h5: theme.textTheme.titleMedium,
              h6: theme.textTheme.titleSmall,
              code: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: colors.surfaceContainerHigh,
              ),
              codeblockDecoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
            ),
          ),
        );
        break;
    }

    // Constrain max height for massive responses
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 500),
      child: SingleChildScrollView(
        child: content,
      ),
    );
  }

  String _getModelDisplayName(String targetId) {
    // Parse "provider:model" format and extract short name
    final colonIndex = targetId.indexOf(':');
    if (colonIndex >= 0 && colonIndex < targetId.length - 1) {
      final modelPart = targetId.substring(colonIndex + 1);
      // Get last part after slash if present
      final slashIndex = modelPart.lastIndexOf('/');
      if (slashIndex >= 0 && slashIndex < modelPart.length - 1) {
        return modelPart.substring(slashIndex + 1);
      }
      return modelPart;
    }
    return targetId;
  }

  String _formatDuration(double seconds) {
    if (seconds < 1) {
      return '${(seconds * 1000).round()}ms';
    } else if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)}s';
    } else {
      final minutes = (seconds / 60).floor();
      final remainingSeconds = (seconds % 60).round();
      return '${minutes}m ${remainingSeconds}s';
    }
  }
}
