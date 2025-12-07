import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../models/project.dart';
import '../models/ws_message_type.dart';
import '../providers/parallel_ai_provider.dart';
import 'batch_tool_preview_widget.dart';

/// Widget that displays parallel AI responses in a swipable PageView
class ParallelResponseWidget extends ConsumerStatefulWidget {
  final Map<String, ModelResponse> responses;
  final List<Project> projects;
  final void Function(String targetId) onToolInteraction;
  final void Function(String targetId, List<ToolStatus> statuses, String? message)
      onToolConfirm;

  const ParallelResponseWidget({
    super.key,
    required this.responses,
    required this.projects,
    required this.onToolInteraction,
    required this.onToolConfirm,
  });

  @override
  ConsumerState<ParallelResponseWidget> createState() =>
      _ParallelResponseWidgetState();
}

class _ParallelResponseWidgetState
    extends ConsumerState<ParallelResponseWidget> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Sort responses by targetId for consistent ordering
    final sortedResponses = widget.responses.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sortedResponses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // PageView with responses
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: sortedResponses.length,
            onPageChanged: (index) {
              ref.read(parallelAiProvider.notifier).setCurrentPage(index);
            },
            itemBuilder: (context, index) {
              final entry = sortedResponses[index];
              return _buildResponseCard(
                context,
                entry.key,
                entry.value,
                theme,
                colors,
              );
            },
          ),
        ),

        // Dot indicators
        if (sortedResponses.length > 1)
          _buildPageIndicator(sortedResponses.length, theme, colors),
      ],
    );
  }

  Widget _buildResponseCard(
    BuildContext context,
    String targetId,
    ModelResponse response,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final modelName = _getModelDisplayName(targetId);

    return Container(
      margin: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Model name badge header
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.robot(),
                        size: Sizes.iconSm,
                        color: colors.onPrimaryContainer,
                      ),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        modelName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (response.duration != null)
                  Text(
                    _formatDuration(response.duration!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                _buildStatusBadge(response.status, theme, colors),
              ],
            ),
          ),

          const Divider(height: 1),

          // Response content
          Expanded(
            child: _buildResponseContent(
              context,
              targetId,
              response,
              theme,
              colors,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    ResponseStatus status,
    ThemeData theme,
    ColorScheme colors,
  ) {
    if (status == ResponseStatus.pending) {
      return const SizedBox.shrink();
    }

    final (label, bgColor, textColor) = switch (status) {
      ResponseStatus.success => ('Done', colors.tertiaryContainer, colors.onTertiaryContainer),
      ResponseStatus.error => ('Error', colors.errorContainer, colors.onErrorContainer),
      ResponseStatus.toolsPending => ('Tools', colors.secondaryContainer, colors.onSecondaryContainer),
      ResponseStatus.pending => ('...', colors.surfaceContainer, colors.onSurfaceVariant),
    };

    return Container(
      margin: const EdgeInsets.only(left: Spacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: textColor),
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
    switch (response.status) {
      case ResponseStatus.pending:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: Spacing.md),
              Text(
                'Waiting for response...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );

      case ResponseStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  PhosphorIcons.warning(),
                  size: 48,
                  color: colors.error,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  response.error ?? 'Unknown error',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );

      case ResponseStatus.toolsPending:
        if (response.toolCalls == null || response.toolCalls!.isEmpty) {
          return const Center(child: Text('No tools'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.sm),
          child: BatchToolPreviewWidget(
            toolCalls: response.toolCalls!,
            projects: widget.projects,
            onBatchConfirm: (statuses) {
              widget.onToolInteraction(targetId);
              widget.onToolConfirm(targetId, statuses, null);
            },
            onSendWithMessage: (statuses, message) {
              widget.onToolInteraction(targetId);
              widget.onToolConfirm(targetId, statuses, message);
            },
          ),
        );

      case ResponseStatus.success:
        return SingleChildScrollView(
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
    }
  }

  Widget _buildPageIndicator(int count, ThemeData theme, ColorScheme colors) {
    final currentPage = ref.watch(parallelAiProvider).currentPageIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final isActive = index == currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 16 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? colors.primary
                  : colors.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
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
