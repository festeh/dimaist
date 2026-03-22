import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../models/ai_model.dart';
import '../providers/service_providers.dart';
import '../services/logging_service.dart';
import '../services/ai_websocket_service.dart';
import '../models/ws_message_type.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../providers/ai_model_provider.dart';
import '../providers/asr_language_provider.dart';
import '../providers/include_completed_provider.dart';
import '../providers/parallel_ai_provider.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/tool_preview_widget.dart';
import '../widgets/model_display.dart';
import '../widgets/model_list_dialog.dart';
import '../widgets/parallel_response_widget.dart';

/// Items that can appear in the chat history
sealed class ChatItem {}

/// A conversation turn: user message + selected AI response
class ConversationTurn extends ChatItem {
  final ChatMessage userMessage;
  final ModelResponse? response; // null while waiting, set when finalized

  ConversationTurn({required this.userMessage, this.response});

  ConversationTurn withResponse(ModelResponse response) =>
      ConversationTurn(userMessage: userMessage, response: response);
}

/// A system event shown inline in the chat (e.g. connection lost/restored)
class SystemEvent extends ChatItem {
  final String text;
  final DateTime timestamp;

  SystemEvent(this.text) : timestamp = DateTime.now();
}

class ChatMessage {
  final String text;
  final String role; // 'user', 'assistant', 'system'
  final DateTime timestamp;
  final double? duration; // duration in seconds
  final List<String>? imageDataUris; // base64 data URIs for attached images
  late final List<Uint8List>? _decodedImages;

  ChatMessage({
    required this.text,
    required this.role,
    required this.timestamp,
    this.duration,
    this.imageDataUris,
  }) {
    _decodedImages = imageDataUris?.map((dataUri) {
      final base64Str = dataUri.split(',').last;
      return Uint8List.fromList(base64Decode(base64Str));
    }).toList();
  }

  List<Uint8List>? get decodedImages => _decodedImages;

  // Helper getter for backward compatibility
  bool get isUser => role == 'user';

  // Format duration for display
  String? get formattedDuration {
    if (duration == null) return null;
    if (duration! < 1) {
      return '${(duration! * 1000).round()}ms';
    } else if (duration! < 60) {
      return '${duration!.toStringAsFixed(1)}s';
    } else {
      final minutes = (duration! / 60).floor();
      final seconds = (duration! % 60).round();
      return '${minutes}m ${seconds}s';
    }
  }
}

class AiChatScreen extends ConsumerStatefulWidget {
  final List<int>? initialAudioBytes;
  final AiPrompt? initialPrompt;
  final int? currentProjectId;
  final String? currentViewName;

  const AiChatScreen({
    super.key,
    this.initialAudioBytes,
    this.initialPrompt,
    this.currentProjectId,
    this.currentViewName,
  });

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  // Conversation history (turns + system events)
  final List<ChatItem> _history = [];

  // Current turn state (in progress)
  ChatMessage? _currentUserMessage;
  final Map<String, ModelResponse> _currentResponses = {};
  bool _allResponsesComplete = false;
  String? _selectedParallelModel; // When set, user committed to this model
  int _currentTurnId = 0; // Tracks current turn, used to filter stale responses

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiWebSocketService _wsService = AiWebSocketService();
  bool _isProcessing = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);

    // If we have initial audio bytes, process them immediately
    if (widget.initialAudioBytes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processAudioMessage(widget.initialAudioBytes!);
      });
    }

    // If we have initial prompt, process it immediately
    if (widget.initialPrompt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processTextMessage(
          widget.initialPrompt!.text,
          images: widget.initialPrompt!.images,
        );
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    _wsService.close();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Use jumpTo for immediate scroll, then let user see the result
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _processAudioMessage(List<int> audioBytes) async {
    if (_isProcessing) return;

    setState(() {
      // Show transcribing indicator as current user message
      _currentUserMessage = ChatMessage(
        text: '🎤 Transcribing...',
        role: 'user',
        timestamp: DateTime.now(),
      );
      _isProcessing = true;
    });

    _scrollToBottom();

    try {
      // Get ASR language setting
      final asrLanguage = ref.read(asrLanguageProvider);

      // Transcribe audio using ASR service directly
      final transcribedText = await ref
          .read(asrServiceProvider)
          .transcribe(audioBytes, asrLanguage.code);

      if (transcribedText.isEmpty) {
        setState(() {
          _currentUserMessage = null;
          _isProcessing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not transcribe audio')),
          );
        }
        return;
      }

      // Update user message with transcribed text
      setState(() {
        _currentUserMessage = ChatMessage(
          text: transcribedText,
          role: 'user',
          timestamp: _currentUserMessage!.timestamp,
        );
      });
      _scrollToBottom();

      // Now send the transcribed text to the AI
      await _sendTextMessage(transcribedText, addUserMessage: false);
    } catch (e) {
      LoggingService.logger.severe('Error processing audio: $e');
      setState(() {
        // On error, add an error response to current turn
        _currentResponses['error'] = ModelResponse(
          targetId: 'error',
          error: 'Failed to process audio',
          status: ResponseStatus.error,
        );
        _isProcessing = false;
        _allResponsesComplete = true;
      });
      _scrollToBottom();
    }
  }

  Future<void> _processTextMessage(
    String message, {
    List<String>? images,
  }) async {
    await _sendTextMessage(message, images: images);
  }

  Future<void> _sendTextMessage(
    String userMessage, {
    bool addUserMessage = true,
    List<String>? images,
  }) async {
    if (userMessage.trim().isEmpty && (images == null || images.isEmpty))
      return;
    // Note: ChatInputWidget already controls when input is enabled based on response state

    final message = userMessage.trim();

    // Check if any models are selected
    final parallelState = ref.read(parallelAiProvider);
    if (parallelState.selectedModelIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one AI model')),
        );
      }
      return;
    }

    // All requests use parallel path (unified flow for 1 or N models)
    await _sendParallelMessage(
      message,
      addUserMessage: addUserMessage,
      images: images,
    );
  }

  /// Get the currently selected/viewed response (for finalizing turns)
  ModelResponse? _getSelectedResponse() {
    if (_currentResponses.isEmpty) return null;

    final currentPage = ref.read(parallelAiProvider).currentPageIndex;

    // Apply same sorting as ParallelResponseWidget._completedResponses
    final sortedResponses =
        _currentResponses.entries
            .where(
              (e) =>
                  e.value.status != ResponseStatus.pending &&
                  (e.value.status != ResponseStatus.error ||
                      _allResponsesComplete),
            )
            .toList()
          ..sort((a, b) {
            final aIsError = a.value.status == ResponseStatus.error;
            final bIsError = b.value.status == ResponseStatus.error;
            if (aIsError != bIsError) return aIsError ? 1 : -1;
            return (a.value.duration ?? double.infinity).compareTo(
              b.value.duration ?? double.infinity,
            );
          });

    if (currentPage < sortedResponses.length) {
      return sortedResponses[currentPage].value;
    }
    return sortedResponses.isNotEmpty ? sortedResponses.first.value : null;
  }

  Future<void> _sendParallelMessage(
    String userMessage, {
    bool addUserMessage = true,
    List<String>? images,
  }) async {
    final message = userMessage.trim();
    final parallelState = ref.read(parallelAiProvider);
    final modelState = ref.read(aiModelProvider);

    // Build target list from selected model IDs, filtering invalid ones
    final validIds = parallelState.selectedModelIds
        .where((id) => modelState.models.any((m) => m.id == id))
        .toSet();

    // If selection became invalid, clear it and close chat
    if (validIds.isEmpty) {
      ref.read(parallelAiProvider.notifier).clearSelection();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Update selection if some models were removed
    if (validIds.length != parallelState.selectedModelIds.length) {
      ref.read(parallelAiProvider.notifier).setSelectedModels(validIds);
    }

    final targets = validIds.map((id) {
      return TargetSpec(model: id);
    }).toList();

    setState(() {
      // Finalize previous turn if exists
      if (_currentUserMessage != null && _currentResponses.isNotEmpty) {
        final selectedResponse = _getSelectedResponse();
        _history.add(
          ConversationTurn(
            userMessage: _currentUserMessage!,
            response: selectedResponse,
          ),
        );
      }

      // Start new turn
      _currentTurnId++; // Increment turn ID to filter stale responses
      if (addUserMessage) {
        _currentUserMessage = ChatMessage(
          text: message,
          role: 'user',
          timestamp: DateTime.now(),
          imageDataUris: images,
        );
      }
      _isProcessing = true;
      _currentResponses.clear();
      _allResponsesComplete = false;
      _selectedParallelModel = null;
    });

    // Scroll to bottom immediately after user message is added
    _scrollToBottom();

    // Initialize parallel state
    ref.read(parallelAiProvider.notifier).startParallelRequest();

    try {
      final baseUrl = ref.read(apiServiceProvider).baseUrl;
      final includeCompleted = ref.read(includeCompletedInAiProvider);

      if (!_wsService.isConnected) {
        _wsService.connect(
          baseUrl: baseUrl,
          onMessage: _handleParallelWSMessage,
          onConnectionClosed: () async {
            setState(() {
              _isProcessing = false;
              _history.add(SystemEvent('Connection lost'));
            });
            _scrollToBottom();
            try {
              await ref.read(taskProvider.notifier).syncData();
            } catch (e) {
              LoggingService.logger.warning('Failed to sync after AI: $e');
            }
          },
          onError: (error) {
            LoggingService.logger.severe('WebSocket error: $error');
            setState(() {
              _isProcessing = false;
            });
          },
        );
        _wsService.sendStart(
          message: message,
          targets: targets,
          includeCompleted: includeCompleted,
          currentProjectId: widget.currentProjectId,
          currentViewName: widget.currentViewName,
          images: images,
        );
      } else {
        _wsService.sendContinue(message, images: images);
      }
    } catch (e) {
      LoggingService.logger.severe('Error sending parallel AI request: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _handleParallelWSMessage(WSMessageType type, Map<String, dynamic> data) {
    // Filter stale responses from previous turns
    final turnId = data['turn_id'] as int?;
    if (turnId != null && turnId != _currentTurnId) {
      LoggingService.logger.fine(
        'Ignoring stale response from turn $turnId (current: $_currentTurnId)',
      );
      return;
    }

    // Get target ID - from message or fall back to selected/default
    final targetId =
        data['target_id'] as String? ?? _selectedParallelModel ?? 'default';

    switch (type) {
      case WSMessageType.thinking:
        break;

      case WSMessageType.modelResponse:
        final response = data['response'] as String? ?? '';
        final duration = data['duration'] as double?;

        setState(() {
          _currentResponses[targetId] = ModelResponse(
            targetId: targetId,
            content: response,
            duration: duration,
            status: ResponseStatus.success,
          );
        });
        ref
            .read(parallelAiProvider.notifier)
            .addModelResponse(
              ModelResponse(
                targetId: targetId,
                content: response,
                duration: duration,
                status: ResponseStatus.success,
              ),
            );
        break;

      case WSMessageType.modelError:
        final error = data['error'] as String? ?? 'Unknown error';
        final duration = data['duration'] as double?;

        setState(() {
          _currentResponses[targetId] = ModelResponse(
            targetId: targetId,
            error: error,
            duration: duration,
            status: ResponseStatus.error,
          );
        });
        ref
            .read(parallelAiProvider.notifier)
            .addModelResponse(
              ModelResponse(
                targetId: targetId,
                error: error,
                duration: duration,
                status: ResponseStatus.error,
              ),
            );
        break;

      case WSMessageType.toolsPending:
        final toolCallsJson = data['tool_calls'] as List<dynamic>? ?? [];
        final duration = data['duration'] as double?;
        if (toolCallsJson.isEmpty) {
          LoggingService.logger.warning('Received tools_pending with no tools');
          break;
        }

        final toolCalls = toolCallsJson
            .map((tc) => PendingToolCall.fromJson(tc as Map<String, dynamic>))
            .toList();

        setState(() {
          _currentResponses[targetId] = ModelResponse(
            targetId: targetId,
            toolCalls: toolCalls,
            duration: duration,
            status: ResponseStatus.toolsPending,
          );
        });
        ref
            .read(parallelAiProvider.notifier)
            .addModelResponse(
              ModelResponse(
                targetId: targetId,
                toolCalls: toolCalls,
                duration: duration,
                status: ResponseStatus.toolsPending,
              ),
            );
        _scrollToBottom();
        break;

      case WSMessageType.allComplete:
        setState(() {
          _isProcessing = false;
          _allResponsesComplete = true;
        });
        ref.read(parallelAiProvider.notifier).setAllComplete();
        break;

      case WSMessageType.toolResult:
        ref.read(taskProvider.notifier).syncData();
        break;

      case WSMessageType.finalResponse:
        final response = data['response'] as String? ?? '';
        final duration = data['duration'] as double?;
        setState(() {
          _currentResponses[targetId] = ModelResponse(
            targetId: targetId,
            content: response,
            duration: duration,
            status: ResponseStatus.success,
          );
        });
        _scrollToBottom();
        break;

      case WSMessageType.error:
        final error = data['error'] as String? ?? 'Unknown error';
        setState(() {
          _currentResponses[targetId] = ModelResponse(
            targetId: targetId,
            error: error,
            status: ResponseStatus.error,
          );
        });
        _scrollToBottom();
        break;

      default:
        LoggingService.logger.warning('Unhandled message type: $type');
    }
  }

  void _handleToolInteractionParallel(String targetId) {
    // User engaged with tools from this model - it wins
    ref.read(parallelAiProvider.notifier).selectWinningModel(targetId);

    setState(() {
      // Lock to this model - response stays in _currentResponses
      _selectedParallelModel = targetId;
    });

    _wsService.selectModel(targetId);
  }

  void _handleToolConfirmSingle(
    String targetId,
    String toolCallId,
    Map<String, dynamic> args,
  ) {
    // User confirmed a single tool from this model
    ref.read(parallelAiProvider.notifier).selectWinningModel(targetId);

    setState(() {
      // Lock to this model (keeps responses visible, disables navigation)
      _selectedParallelModel = targetId;
    });

    _wsService.confirmTool(targetId, toolCallId, args);
  }

  Widget _buildSystemEvent(SystemEvent event) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      child: Center(
        child: Text(
          event.text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.xs,
      ),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: _TypingDots(color: colors.onSurfaceVariant),
    );
  }

  /// Flat list of history items for rendering (turns expand to 2 items, events to 1)
  List<Object> get _flatHistoryItems {
    final items = <Object>[];
    for (final item in _history) {
      switch (item) {
        case ConversationTurn turn:
          items.add(turn.userMessage);
          items.add(turn); // response slot
        case SystemEvent event:
          items.add(event);
      }
    }
    return items;
  }

  /// Calculate total list item count for history + current turn
  int _getListItemCount() {
    int count = _flatHistoryItems.length;

    // Current turn user message
    if (_currentUserMessage != null) {
      count += 1;
    }

    // Current turn responses (parallel widget or typing indicator)
    if (_currentResponses.isNotEmpty) {
      count += 1;
    } else if (_isProcessing) {
      count += 1; // Typing indicator
    }

    return count;
  }

  /// Build list item at index - renders history items, then current turn
  Widget _buildListItem(int index, List<dynamic> projects) {
    final flat = _flatHistoryItems;

    if (index < flat.length) {
      final item = flat[index];
      if (item is ChatMessage) {
        return _buildUserMessage(item);
      } else if (item is ConversationTurn) {
        return _buildHistoryResponse(item.response, projects);
      } else if (item is SystemEvent) {
        return _buildSystemEvent(item);
      }
    }

    // Current turn items
    final currentTurnIndex = index - flat.length;

    // Current user message (index 0 in current turn)
    if (_currentUserMessage != null && currentTurnIndex == 0) {
      return _buildUserMessage(_currentUserMessage!);
    }

    // Current responses or typing indicator (index 1 if user message exists, else 0)
    final responsesIndex = _currentUserMessage != null ? 1 : 0;
    if (currentTurnIndex == responsesIndex) {
      if (_currentResponses.isNotEmpty) {
        return ParallelResponseWidget(
          responses: _currentResponses,
          projects: projects.cast(),
          allComplete: _allResponsesComplete,
          onToolInteraction: _handleToolInteractionParallel,
          onToolConfirmSingle: _handleToolConfirmSingle,
          lockedToModel: _selectedParallelModel,
        );
      } else if (_isProcessing) {
        return _buildTypingIndicator();
      }
    }

    return const SizedBox.shrink();
  }

  /// Build a user message bubble
  Widget _buildUserMessage(ChatMessage message) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.md,
              ),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.decodedImages != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Wrap(
                        spacing: Spacing.xs,
                        runSpacing: Spacing.xs,
                        children: message.decodedImages!.map((bytes) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.sm),
                            child: Image.memory(
                              bytes,
                              width: 200,
                              fit: BoxFit.cover,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  if (message.text.isNotEmpty)
                    SelectableText(
                      message.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a history response (finalized, no arrows)
  Widget _buildHistoryResponse(
    ModelResponse? response,
    List<dynamic> projects,
  ) {
    if (response == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // For tool calls, show the BatchToolPreviewWidget in completed state
    if (response.status == ResponseStatus.toolsPending &&
        response.toolCalls != null) {
      return Container(
        margin: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.xs,
        ),
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: response.toolCalls!.map((tc) {
            return ToolPreviewWidget(
              toolName: tc.name,
              arguments: tc.arguments,
              projects: projects.cast(),
              status: ToolPreviewStatus.confirmed,
              onConfirm: (_) {},
              onReject: () {},
            );
          }).toList(),
        ),
      );
    }

    // For text responses
    if (response.status == ResponseStatus.success && response.content != null) {
      return Container(
        margin: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.xs,
        ),
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: response.content!,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                ),
                h1: theme.textTheme.titleLarge?.copyWith(
                  color: colors.onSurface,
                ),
                h2: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                ),
                h3: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                ),
                code: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontFamily: 'monospace',
                  backgroundColor: colors.surfaceContainerHigh,
                ),
                codeblockDecoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
              ),
            ),
            if (response.duration != null)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.sm),
                child: Text(
                  _formatDuration(response.duration!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // For errors
    if (response.status == ResponseStatus.error) {
      return Container(
        margin: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.xs,
        ),
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Text(
          'Error: ${response.error ?? "Unknown error"}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onErrorContainer,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
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

  @override
  Widget build(BuildContext context) {
    final modelState = ref.watch(aiModelProvider);
    final parallelState = ref.watch(parallelAiProvider);
    final projectsAsync = ref.watch(projectProvider);
    final projects = projectsAsync.value ?? [];
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    // Get selected models for display
    final selectedIds = parallelState.selectedModelIds;
    final selectedModels = selectedIds
        .map((id) => modelState.models.where((m) => m.id == id).firstOrNull)
        .whereType<AiModel>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => showDialog(
            context: context,
            builder: (context) => const ModelListDialog(),
          ),
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedModels.isEmpty)
                  Text('Select Model', style: theme.textTheme.titleMedium)
                else if (selectedModels.length == 1)
                  ModelDisplay(model: selectedModels.first)
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.stackSimple(),
                        size: Sizes.iconMd,
                        color: colors.primary,
                      ),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        '${selectedModels.length} models',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: Spacing.xs),
                PhosphorIcon(
                  PhosphorIcons.caretDown(),
                  size: Sizes.iconSm,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _getListItemCount(),
              itemBuilder: (context, index) => _buildListItem(index, projects),
            ),
          ),
          ChatInputWidget(
            onSendMessage: (prompt) =>
                _sendTextMessage(prompt.text, images: prompt.images),
            onAudioRecorded: _processAudioMessage,
            // Enable input once first response arrives (even if still waiting for others)
            isProcessing:
                _isProcessing &&
                !_currentResponses.values.any(
                  (r) => r.status != ResponseStatus.pending,
                ),
          ),
        ],
      ),
    );
  }
}

/// Animated typing dots indicator
class _TypingDots extends StatefulWidget {
  final Color color;

  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0,
        end: 1,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    // Start animations with staggered delay
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
              child: Opacity(
                opacity: 0.3 + (_animations[index].value * 0.7),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
