import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../repositories/providers.dart';
import '../services/settings_service.dart';
import '../services/logging_service.dart';
import '../providers/task_provider.dart';
import '../widgets/recording_dialog.dart';
import '../widgets/chat_input_widget.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
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
  bool _isProcessing = false;
  bool _hasText = false;
  String? _statusMessage;

  String _getCondensedModelName(String fullPath) {
    final parts = fullPath.split('/');
    if (parts.length >= 3) {
      return '${parts.first.substring(0, 1)}/${parts.last}';
    }
    return fullPath;
  }

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

  Future<void> _processAudioMessage(List<int> audioBytes) async {
    if (_isProcessing) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: '🎤 Transcribing...',
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isProcessing = true;
      _statusMessage = 'Transcribing audio...';
    });

    _scrollToBottom();

    try {
      final model = SettingsService.instance.aiModel.value;
      String aiResponse = '';
      bool transcriptionReceived = false;

      await ref
          .read(apiServiceProvider)
          .sendAudioStream(
            audioBytes,
            model,
            (chunk) {
              setState(() {
                aiResponse += chunk;
                if (_messages.isNotEmpty && !_messages.last.isUser) {
                  _messages.last = ChatMessage(
                    text: aiResponse,
                    isUser: false,
                    timestamp: _messages.last.timestamp,
                  );
                } else {
                  _messages.add(
                    ChatMessage(
                      text: aiResponse,
                      isUser: false,
                      timestamp: DateTime.now(),
                    ),
                  );
                }
              });
              _scrollToBottom();
            },
            () async {
              setState(() {
                _isProcessing = false;
                _statusMessage = null;
              });
              try {
                await ref.read(taskProvider.notifier).syncData();
              } catch (e) {
                LoggingService.logger.warning(
                  'Failed to sync after audio AI: $e',
                );
              }
            },
            onStatus: (status) {
              setState(() {
                _statusMessage = status;
              });
            },
            onTranscription: (transcribedText) {
              // Update the user message with the actual transcribed text
              if (_messages.isNotEmpty &&
                  _messages.last.isUser &&
                  !transcriptionReceived) {
                setState(() {
                  _messages.last = ChatMessage(
                    text: transcribedText,
                    isUser: true,
                    timestamp: _messages.last.timestamp,
                  );
                  transcriptionReceived = true;
                });
                _scrollToBottom();
              }
            },
          );
    } catch (e) {
      LoggingService.logger.severe('Error processing audio: $e');
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Error: Failed to process audio',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isProcessing = false;
        _statusMessage = null;
      });
      _scrollToBottom();
    }
  }

  Future<void> _processTextMessage(String message) async {
    await _sendTextMessage(message);
  }

  Future<void> _sendTextMessage(String userMessage) async {
    if (userMessage.trim().isEmpty || _isProcessing) return;

    final message = userMessage.trim();

    setState(() {
      _messages.add(
        ChatMessage(text: message, isUser: true, timestamp: DateTime.now()),
      );
      _isProcessing = true;
      _statusMessage = 'Initializing...';
    });

    _scrollToBottom();

    try {
      final model = SettingsService.instance.aiModel.value;
      String aiResponse = '';

      await ref
          .read(apiServiceProvider)
          .sendTextAIStream(
            message,
            model,
            (chunk) {
              setState(() {
                aiResponse += chunk;
                if (_messages.isNotEmpty && !_messages.last.isUser) {
                  _messages.last = ChatMessage(
                    text: aiResponse,
                    isUser: false,
                    timestamp: _messages.last.timestamp,
                  );
                } else {
                  _messages.add(
                    ChatMessage(
                      text: aiResponse,
                      isUser: false,
                      timestamp: DateTime.now(),
                    ),
                  );
                }
              });
              _scrollToBottom();
            },
            () async {
              setState(() {
                _isProcessing = false;
                _statusMessage = null;
              });
              try {
                await ref.read(taskProvider.notifier).syncData();
              } catch (e) {
                LoggingService.logger.warning(
                  'Failed to sync after text AI: $e',
                );
              }
            },
            onStatus: (status) {
              setState(() {
                _statusMessage = status;
              });
            },
          );
    } catch (e) {
      LoggingService.logger.severe('Error sending AI request: $e');
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Error: Failed to get AI response',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isProcessing = false;
        _statusMessage = null;
      });
      _scrollToBottom();
    }
  }

  Widget _buildMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.deepPurple[600],
              child: const Icon(Icons.smart_toy, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: message.isUser
                  ? SelectableText(
                      message.text,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : MarkdownBody(
                      data: message.text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        code: TextStyle(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (!_isProcessing || _statusMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(_statusMessage!)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentModel = SettingsService.instance.aiModel.value;
    final condensedModelName = _getCondensedModelName(currentModel);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Chat ($condensedModelName)'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          _buildStatusIndicator(),
          ChatInputWidget(
            onSendMessage: _sendTextMessage,
            onAudioRecorded: _processAudioMessage,
            isProcessing: _isProcessing,
          ),
        ],
      ),
    );
  }
}
