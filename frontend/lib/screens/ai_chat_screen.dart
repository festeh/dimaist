import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../models/ai_model.dart';
import '../repositories/providers.dart';
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
import '../widgets/batch_tool_preview_widget.dart';
import '../widgets/model_display.dart';
import '../widgets/model_list_dialog.dart';
import '../widgets/parallel_response_widget.dart';

enum MessageType { normal, toolCall, toolResult, toolPreview, batchToolPreview }

class ChatMessage {
  final String text;
  final String role; // 'user', 'assistant', 'system'
  final DateTime timestamp;
  final MessageType type;
  final Map<String, dynamic>? metadata; // for tool details
  final double? duration; // duration in seconds

  ChatMessage({
    required this.text,
    required this.role,
    required this.timestamp,
    this.type = MessageType.normal,
    this.metadata,
    this.duration,
  });

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

  // Convert to API format
  Map<String, dynamic> toApiFormat() {
    final apiMessage = {'role': role, 'content': text};

    // Add tool-specific fields if needed
    if (metadata != null) {
      if (metadata!.containsKey('tool_calls')) {
        apiMessage['tool_calls'] = metadata!['tool_calls'];
      }
      if (metadata!.containsKey('tool_call_id')) {
        apiMessage['tool_call_id'] = metadata!['tool_call_id'];
      }
    }

    return apiMessage;
  }
}

class AiChatScreen extends ConsumerStatefulWidget {
  final List<int>? initialAudioBytes;
  final String? initialMessage;

  const AiChatScreen({super.key, this.initialAudioBytes, this.initialMessage});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiWebSocketService _wsService = AiWebSocketService();
  bool _isProcessing = false;
  bool _hasText = false;

  // Index of the pending tool preview message (if any) - legacy single tool
  int? _pendingToolMessageIndex;

  // Index of batch tool preview message (if any)
  int? _batchToolMessageIndex;

  // Parallel mode state
  bool _isParallelMode = false;
  final Map<String, ModelResponse> _parallelResponses = {};

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);

    // Initialize parallel provider with default selection if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final parallelState = ref.read(parallelAiProvider);
      if (parallelState.selectedModelIds.isEmpty) {
        final modelState = ref.read(aiModelProvider);
        if (modelState.selectedModelId != null) {
          ref.read(parallelAiProvider.notifier).setSelectedModels({modelState.selectedModelId!});
        } else if (modelState.models.isNotEmpty) {
          ref.read(parallelAiProvider.notifier).setSelectedModels({modelState.models.first.id});
        }
      }
    });

    // If we have initial audio bytes, process them immediately
    if (widget.initialAudioBytes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processAudioMessage(widget.initialAudioBytes!);
      });
    }

    // If we have initial text message, process it immediately
    if (widget.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processTextMessage(widget.initialMessage!);
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
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Map<String, dynamic>> _buildMessagesFromHistory() {
    // Only include normal user/assistant messages for API context
    // Tool calls and results are UI indicators, not conversation messages
    return _messages
        .where((msg) => msg.type == MessageType.normal)
        .map((msg) => msg.toApiFormat())
        .toList();
  }

  Future<void> _processAudioMessage(List<int> audioBytes) async {
    if (_isProcessing) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: '🎤 Transcribing...',
          role: 'user',
          timestamp: DateTime.now(),
        ),
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
          _messages.removeLast();
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
        _messages.last = ChatMessage(
          text: transcribedText,
          role: 'user',
          timestamp: _messages.last.timestamp,
        );
      });
      _scrollToBottom();

      // Now send the transcribed text to the AI
      await _sendTextMessage(transcribedText, addUserMessage: false);
    } catch (e) {
      LoggingService.logger.severe('Error processing audio: $e');
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Error: Failed to process audio',
            role: 'assistant',
            timestamp: DateTime.now(),
          ),
        );
        _isProcessing = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _processTextMessage(String message) async {
    await _sendTextMessage(message);
  }

  Future<void> _sendTextMessage(String userMessage, {bool addUserMessage = true}) async {
    if (userMessage.trim().isEmpty) return;
    if (addUserMessage && _isProcessing) return;

    final message = userMessage.trim();

    // Check if parallel mode (multiple models selected)
    final parallelState = ref.read(parallelAiProvider);
    if (parallelState.selectedModelIds.length > 1) {
      await _sendParallelMessage(message, addUserMessage: addUserMessage);
      return;
    }

    setState(() {
      if (addUserMessage) {
        _messages.add(
          ChatMessage(text: message, role: 'user', timestamp: DateTime.now()),
        );
      }
      _isProcessing = true;
      _pendingToolMessageIndex = null;
      _batchToolMessageIndex = null;
    });

    _scrollToBottom();

    try {
      // Get single selected model from parallel provider
      final parallelState = ref.read(parallelAiProvider);
      final modelState = ref.read(aiModelProvider);
      final selectedId = parallelState.selectedModelIds.first;
      final selectedModel = modelState.models.firstWhere((m) => m.id == selectedId);
      final provider = selectedModel.provider.name;
      final model = selectedModel.modelName;

      // Build complete messages array including the user message
      final messagesHistory = _buildMessagesFromHistory();
      final allMessages =
          addUserMessage
              ? messagesHistory + [{'role': 'user', 'content': message}]
              : messagesHistory;

      // Connect and start WebSocket conversation
      final baseUrl = ref.read(apiServiceProvider).baseUrl;
      final includeCompleted = ref.read(includeCompletedInAiProvider);
      _wsService.connect(baseUrl);

      _wsService.startConversation(
        messages: allMessages,
        provider: provider,
        model: model,
        includeCompleted: includeCompleted,
        onMessage: _handleWSMessage,
        onDone: () async {
          setState(() {
            _isProcessing = false;
            _pendingToolMessageIndex = null;
            _batchToolMessageIndex = null;
          });
          _wsService.close();
          try {
            await ref.read(taskProvider.notifier).syncData();
          } catch (e) {
            LoggingService.logger.warning(
              'Failed to sync after AI: $e',
            );
          }
        },
        onError: (error) {
          LoggingService.logger.severe('WebSocket error: $error');
          setState(() {
            _messages.add(
              ChatMessage(
                text: 'Error: $error',
                role: 'assistant',
                timestamp: DateTime.now(),
              ),
            );
            _isProcessing = false;
          });
          _scrollToBottom();
        },
      );
    } catch (e) {
      LoggingService.logger.severe('Error sending AI request: $e');
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Error: Failed to get AI response',
            role: 'assistant',
            timestamp: DateTime.now(),
          ),
        );
        _isProcessing = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendParallelMessage(String userMessage, {bool addUserMessage = true}) async {
    final message = userMessage.trim();
    final parallelState = ref.read(parallelAiProvider);
    final modelState = ref.read(aiModelProvider);

    // Build target list from selected model IDs
    final targets = parallelState.selectedModelIds.map((id) {
      final model = modelState.models.firstWhere((m) => m.id == id);
      return TargetSpec(provider: model.provider.name, model: model.modelName);
    }).toList();

    setState(() {
      if (addUserMessage) {
        _messages.add(
          ChatMessage(text: message, role: 'user', timestamp: DateTime.now()),
        );
      }
      _isProcessing = true;
      _isParallelMode = true;
      _parallelResponses.clear();
      _pendingToolMessageIndex = null;
      _batchToolMessageIndex = null;
    });

    // Initialize parallel state
    ref.read(parallelAiProvider.notifier).startParallelRequest();

    _scrollToBottom();

    try {
      final messagesHistory = _buildMessagesFromHistory();
      final allMessages = addUserMessage
          ? messagesHistory + [{'role': 'user', 'content': message}]
          : messagesHistory;

      final baseUrl = ref.read(apiServiceProvider).baseUrl;
      final includeCompleted = ref.read(includeCompletedInAiProvider);
      _wsService.connect(baseUrl);

      _wsService.startParallelConversation(
        messages: allMessages,
        targets: targets,
        includeCompleted: includeCompleted,
        onMessage: _handleParallelWSMessage,
        onDone: () async {
          setState(() {
            _isProcessing = false;
          });
          _wsService.close();
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
            _isParallelMode = false;
          });
        },
      );
    } catch (e) {
      LoggingService.logger.severe('Error sending parallel AI request: $e');
      setState(() {
        _isProcessing = false;
        _isParallelMode = false;
      });
    }
  }

  void _handleParallelWSMessage(WSMessageType type, Map<String, dynamic> data) {
    switch (type) {
      case WSMessageType.thinking:
        // Typing indicator shown automatically
        break;

      case WSMessageType.modelResponse:
        final targetId = data['target_id'] as String;
        final response = data['response'] as String? ?? '';
        final duration = data['duration'] as double?;

        setState(() {
          _parallelResponses[targetId] = ModelResponse(
            targetId: targetId,
            content: response,
            duration: duration,
            status: ResponseStatus.success,
          );
        });
        ref.read(parallelAiProvider.notifier).addModelResponse(
          ModelResponse(
            targetId: targetId,
            content: response,
            duration: duration,
            status: ResponseStatus.success,
          ),
        );
        break;

      case WSMessageType.modelError:
        final targetId = data['target_id'] as String;
        final error = data['error'] as String? ?? 'Unknown error';
        final duration = data['duration'] as double?;

        setState(() {
          _parallelResponses[targetId] = ModelResponse(
            targetId: targetId,
            error: error,
            duration: duration,
            status: ResponseStatus.error,
          );
        });
        ref.read(parallelAiProvider.notifier).addModelResponse(
          ModelResponse(
            targetId: targetId,
            error: error,
            duration: duration,
            status: ResponseStatus.error,
          ),
        );
        break;

      case WSMessageType.toolsPending:
        final targetId = data['target_id'] as String?;
        if (targetId != null) {
          // Parallel mode tools pending
          final toolCallsJson = data['tool_calls'] as List<dynamic>? ?? [];
          final duration = data['duration'] as double?;
          final toolCalls = toolCallsJson
              .map((tc) => PendingToolCall.fromJson(tc as Map<String, dynamic>))
              .toList();

          setState(() {
            _parallelResponses[targetId] = ModelResponse(
              targetId: targetId,
              toolCalls: toolCalls,
              duration: duration,
              status: ResponseStatus.toolsPending,
            );
          });
          ref.read(parallelAiProvider.notifier).addModelResponse(
            ModelResponse(
              targetId: targetId,
              toolCalls: toolCalls,
              duration: duration,
              status: ResponseStatus.toolsPending,
            ),
          );
        } else {
          // Single mode - delegate to regular handler
          _handleWSMessage(type, data);
        }
        break;

      case WSMessageType.allComplete:
        setState(() {
          _isProcessing = false;
        });
        ref.read(parallelAiProvider.notifier).setAllComplete();
        break;

      case WSMessageType.finalResponse:
        // In parallel mode after model selection, this is handled like single mode
        _handleWSMessage(type, data);
        break;

      case WSMessageType.error:
        _handleWSMessage(type, data);
        break;

      default:
        LoggingService.logger.warning('Unhandled parallel message type: $type');
    }
  }

  void _handleToolInteractionParallel(String targetId) {
    // User engaged with tools from this model - it wins
    ref.read(parallelAiProvider.notifier).selectWinningModel(targetId);

    setState(() {
      _isParallelMode = false;
      // Add the winning model's response to message history if it was a text response
      final response = _parallelResponses[targetId];
      if (response != null && response.status == ResponseStatus.success && response.content != null) {
        _messages.add(
          ChatMessage(
            text: response.content!,
            role: 'assistant',
            timestamp: DateTime.now(),
            duration: response.duration,
          ),
        );
      }
    });

    _wsService.selectModel(targetId);
  }

  void _handleToolConfirmParallel(String targetId, List<ToolStatus> statuses, String? message) {
    // User confirmed tools from this model
    ref.read(parallelAiProvider.notifier).selectWinningModel(targetId);

    setState(() {
      _isParallelMode = false;
      _isProcessing = true;
      if (message != null && message.isNotEmpty) {
        _messages.add(
          ChatMessage(text: message, role: 'user', timestamp: DateTime.now()),
        );
      }
    });

    _wsService.batchConfirmForModel(targetId, statuses, newMessage: message);
  }

  void _handleWSMessage(WSMessageType type, Map<String, dynamic> data) {
    switch (type) {
      case WSMessageType.thinking:
        // Typing indicator is shown automatically while _isProcessing is true
        break;

      case WSMessageType.toolPending:
        // Legacy single tool - still supported for backwards compatibility
        final toolName = data['tool'] as String?;
        final arguments = data['arguments'] as Map<String, dynamic>?;
        final duration = data['duration'] as double?;
        setState(() {
          _messages.add(
            ChatMessage(
              text: toolName ?? 'Unknown tool',
              role: 'assistant',
              timestamp: DateTime.now(),
              type: MessageType.toolPreview,
              metadata: {
                'tool': toolName,
                'arguments': arguments,
                'status': 'pending',
              },
              duration: duration,
            ),
          );
          _pendingToolMessageIndex = _messages.length - 1;
          _isProcessing = false; // Allow interaction with preview
        });
        _scrollToBottom();
        break;

      case WSMessageType.toolsPending:
        // New batch tools
        final toolCallsJson = data['tool_calls'] as List<dynamic>?;
        final duration = data['duration'] as double?;
        if (toolCallsJson == null || toolCallsJson.isEmpty) {
          LoggingService.logger.warning('Received tools_pending with no tools');
          break;
        }

        final toolCalls = toolCallsJson
            .map((tc) => PendingToolCall.fromJson(tc as Map<String, dynamic>))
            .toList();

        setState(() {
          _messages.add(
            ChatMessage(
              text: '${toolCalls.length} actions pending',
              role: 'assistant',
              timestamp: DateTime.now(),
              type: MessageType.batchToolPreview,
              metadata: {
                'tool_calls': toolCallsJson,
                'status': 'pending',
              },
              duration: duration,
            ),
          );
          _batchToolMessageIndex = _messages.length - 1;
          _isProcessing = false; // Allow interaction with preview
        });
        _scrollToBottom();
        break;

      case WSMessageType.toolResult:
        // Duration already set at toolPending, nothing to do here
        break;

      case WSMessageType.finalResponse:
        final response = data['response'] as String? ?? '';
        final duration = data['duration'] as double?;
        setState(() {
          _messages.add(
            ChatMessage(
              text: response,
              role: 'assistant',
              timestamp: DateTime.now(),
              duration: duration,
            ),
          );
        });
        _scrollToBottom();
        break;

      case WSMessageType.cancelled:
        // Widget already shows "Cancelled" badge, no additional message needed
        break;

      case WSMessageType.error:
        final error = data['error'] as String? ?? 'Unknown error';
        setState(() {
          _messages.add(
            ChatMessage(
              text: 'Error: $error',
              role: 'assistant',
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
        break;

      default:
        LoggingService.logger.warning('Unhandled message type: $type');
    }
  }

  void _confirmTool(Map<String, dynamic> args) {
    if (_pendingToolMessageIndex == null) return;

    // Mark the preview as confirmed, preserving duration
    final oldMessage = _messages[_pendingToolMessageIndex!];
    final newMetadata = Map<String, dynamic>.from(oldMessage.metadata ?? {});
    newMetadata['status'] = 'confirmed';
    newMetadata['arguments'] = args; // Use potentially edited args

    setState(() {
      _messages[_pendingToolMessageIndex!] = ChatMessage(
        text: oldMessage.text,
        role: oldMessage.role,
        timestamp: oldMessage.timestamp,
        type: oldMessage.type,
        metadata: newMetadata,
        duration: oldMessage.duration,
      );
      _pendingToolMessageIndex = null;
      _isProcessing = true;
    });
    _wsService.confirm(args);
  }

  void _rejectTool() {
    if (_pendingToolMessageIndex == null) return;

    // Mark the preview as cancelled, preserving duration
    final oldMessage = _messages[_pendingToolMessageIndex!];
    final newMetadata = Map<String, dynamic>.from(oldMessage.metadata ?? {});
    newMetadata['status'] = 'cancelled';

    setState(() {
      _messages[_pendingToolMessageIndex!] = ChatMessage(
        text: oldMessage.text,
        role: oldMessage.role,
        timestamp: oldMessage.timestamp,
        type: oldMessage.type,
        metadata: newMetadata,
        duration: oldMessage.duration,
      );
      _pendingToolMessageIndex = null;
    });
    _wsService.reject();
  }

  void _batchConfirm(List<ToolStatus> statuses) {
    if (_batchToolMessageIndex == null) return;

    // Mark the batch preview as completed
    final oldMessage = _messages[_batchToolMessageIndex!];
    final newMetadata = Map<String, dynamic>.from(oldMessage.metadata ?? {});
    newMetadata['status'] = 'completed';
    newMetadata['statuses'] = statuses.map((s) => s.toJson()).toList();

    setState(() {
      _messages[_batchToolMessageIndex!] = ChatMessage(
        text: oldMessage.text,
        role: oldMessage.role,
        timestamp: oldMessage.timestamp,
        type: oldMessage.type,
        metadata: newMetadata,
        duration: oldMessage.duration,
      );
      _batchToolMessageIndex = null;
      _isProcessing = true;
    });

    _wsService.batchConfirm(statuses);
  }

  void _batchConfirmWithMessage(List<ToolStatus> statuses, String message) {
    if (_batchToolMessageIndex == null) return;

    // Mark the batch preview as completed
    final oldMessage = _messages[_batchToolMessageIndex!];
    final newMetadata = Map<String, dynamic>.from(oldMessage.metadata ?? {});
    newMetadata['status'] = 'completed';
    newMetadata['statuses'] = statuses.map((s) => s.toJson()).toList();

    setState(() {
      _messages[_batchToolMessageIndex!] = ChatMessage(
        text: oldMessage.text,
        role: oldMessage.role,
        timestamp: oldMessage.timestamp,
        type: oldMessage.type,
        metadata: newMetadata,
        duration: oldMessage.duration,
      );
      // Add user message
      _messages.add(
        ChatMessage(text: message, role: 'user', timestamp: DateTime.now()),
      );
      _batchToolMessageIndex = null;
      _isProcessing = true;
    });

    _wsService.batchConfirm(statuses, newMessage: message);
    _scrollToBottom();
  }

  Widget _buildMessage(ChatMessage message, List<dynamic> projects) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Handle batch tool preview messages
    if (message.type == MessageType.batchToolPreview) {
      return _buildBatchToolPreviewMessage(message, projects);
    }

    // Handle tool preview messages
    if (message.type == MessageType.toolPreview) {
      return _buildToolPreviewMessage(message, projects);
    }

    // User messages - minimal bubble, right-aligned, primary tint
    if (message.isUser) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: SelectableText(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // AI responses - minimal bubble, left-aligned, surface color
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: message.text,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
              h1: theme.textTheme.titleLarge?.copyWith(color: colors.onSurface),
              h2: theme.textTheme.titleMedium?.copyWith(color: colors.onSurface),
              h3: theme.textTheme.titleSmall?.copyWith(color: colors.onSurface),
              h4: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurface, fontWeight: FontWeight.bold),
              h5: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface, fontWeight: FontWeight.bold),
              h6: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface, fontWeight: FontWeight.bold),
              listBullet: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
              em: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface, fontStyle: FontStyle.italic),
              strong: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface, fontWeight: FontWeight.bold),
              a: theme.textTheme.bodyMedium?.copyWith(color: colors.primary, decoration: TextDecoration.underline),
              blockquote: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, fontStyle: FontStyle.italic),
              tableHead: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface, fontWeight: FontWeight.bold),
              tableBody: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
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
          if (message.formattedDuration != null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Text(
                message.formattedDuration!,
                style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolPreviewMessage(ChatMessage message, List<dynamic> projects) {
    final toolName = message.metadata?['tool'] as String? ?? '';
    final arguments = message.metadata?['arguments'] as Map<String, dynamic>? ?? {};
    final statusStr = message.metadata?['status'] as String? ?? 'pending';
    final status = switch (statusStr) {
      'confirmed' => ToolPreviewStatus.confirmed,
      'cancelled' => ToolPreviewStatus.cancelled,
      _ => ToolPreviewStatus.pending,
    };
    final messageIndex = _messages.indexOf(message);
    final isPending = messageIndex == _pendingToolMessageIndex;

    return ToolPreviewWidget(
      toolName: toolName,
      arguments: arguments,
      onConfirm: isPending ? _confirmTool : (_) {},
      onReject: isPending ? _rejectTool : () {},
      projects: projects.cast(),
      status: status,
      duration: message.formattedDuration,
    );
  }

  Widget _buildBatchToolPreviewMessage(ChatMessage message, List<dynamic> projects) {
    final toolCallsJson = message.metadata?['tool_calls'] as List<dynamic>? ?? [];
    final statusStr = message.metadata?['status'] as String? ?? 'pending';
    final messageIndex = _messages.indexOf(message);
    final isPending = messageIndex == _batchToolMessageIndex;

    // If completed, show a summary instead of interactive widget
    if (statusStr == 'completed') {
      final statuses = message.metadata?['statuses'] as List<dynamic>? ?? [];
      final confirmed = statuses.where((s) => s['status'] == 'confirmed').length;
      final rejected = statuses.where((s) => s['status'] == 'rejected').length;

      final theme = Theme.of(context);
      final colors = theme.colorScheme;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Row(
          children: [
            PhosphorIcon(PhosphorIcons.stack(), color: colors.onSurfaceVariant, size: Sizes.iconMd),
            const SizedBox(width: Spacing.sm),
            Text(
              '${toolCallsJson.length} actions: $confirmed confirmed, $rejected rejected',
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (message.formattedDuration != null) ...[
              const SizedBox(width: Spacing.xs),
              Text(
                message.formattedDuration!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Parse tool calls
    final toolCalls = toolCallsJson
        .map((tc) => PendingToolCall.fromJson(tc as Map<String, dynamic>))
        .toList();

    return BatchToolPreviewWidget(
      toolCalls: toolCalls,
      projects: projects.cast(),
      onBatchConfirm: isPending ? _batchConfirm : (_) {},
      onSendWithMessage: isPending ? _batchConfirmWithMessage : (statuses, msg) {},
      duration: message.formattedDuration,
    );
  }

  Widget _buildTypingIndicator() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: _TypingDots(color: colors.onSurfaceVariant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelState = ref.watch(aiModelProvider);
    final parallelState = ref.watch(parallelAiProvider);
    final projectsAsync = ref.watch(projectProvider);
    final projects = projectsAsync.valueOrNull ?? [];
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
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedModels.isEmpty)
                  Text('Select Model', style: theme.textTheme.titleMedium)
                else if (selectedModels.length == 1)
                  ModelDisplay(model: selectedModels.first, iconSize: 20)
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
            child: _isParallelMode && _parallelResponses.isNotEmpty
                ? ParallelResponseWidget(
                    responses: _parallelResponses,
                    projects: projects,
                    onToolInteraction: _handleToolInteractionParallel,
                    onToolConfirm: _handleToolConfirmParallel,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length + (_isProcessing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessage(_messages[index], projects);
                    },
                  ),
          ),
          ChatInputWidget(
            onSendMessage: _sendTextMessage,
            onAudioRecorded: _processAudioMessage,
            isProcessing: _isProcessing || _pendingToolMessageIndex != null || _batchToolMessageIndex != null,
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

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
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
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
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
