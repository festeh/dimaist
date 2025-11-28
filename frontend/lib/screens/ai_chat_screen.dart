import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../config/design_tokens.dart';
import '../repositories/providers.dart';
import '../services/logging_service.dart';
import '../services/ai_websocket_service.dart';
import '../models/ws_message_type.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../providers/ai_model_provider.dart';
import '../providers/asr_language_provider.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/tool_preview_widget.dart';
import '../widgets/model_display.dart';
import '../widgets/model_list_dialog.dart';

enum MessageType { normal, toolCall, toolResult, toolPreview }

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

  // Index of the pending tool preview message (if any)
  int? _pendingToolMessageIndex;

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

    setState(() {
      if (addUserMessage) {
        _messages.add(
          ChatMessage(text: message, role: 'user', timestamp: DateTime.now()),
        );
      }
      _isProcessing = true;
      _pendingToolMessageIndex = null;
    });

    _scrollToBottom();

    try {
      final modelState = ref.read(aiModelProvider);
      final selectedModel = modelState.selectedModel;
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
      _wsService.connect(baseUrl);

      _wsService.startConversation(
        messages: allMessages,
        provider: provider,
        model: model,
        onMessage: _handleWSMessage,
        onDone: () async {
          setState(() {
            _isProcessing = false;
            _pendingToolMessageIndex = null;
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

  void _handleWSMessage(WSMessageType type, Map<String, dynamic> data) {
    switch (type) {
      case WSMessageType.thinking:
        // Typing indicator is shown automatically while _isProcessing is true
        break;

      case WSMessageType.toolPending:
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

  Widget _buildMessage(ChatMessage message, List<dynamic> projects) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
      'confirmed' => ToolStatus.confirmed,
      'cancelled' => ToolStatus.cancelled,
      _ => ToolStatus.pending,
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
    final selectedModel = modelState.selectedModel;
    final projectsAsync = ref.watch(projectProvider);
    final projects = projectsAsync.valueOrNull ?? [];

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
                ModelDisplay(model: selectedModel, iconSize: 20),
                const SizedBox(width: Spacing.xs),
                PhosphorIcon(
                  PhosphorIcons.caretDown(),
                  size: Sizes.iconSm,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
            isProcessing: _isProcessing || _pendingToolMessageIndex != null,
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
