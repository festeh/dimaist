import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/providers.dart';
import '../services/settings_service.dart';
import '../services/logging_service.dart';
import '../providers/task_provider.dart';

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
  
  const AiChatScreen({super.key, this.initialAudioBytes});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isProcessing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    
    // If we have initial audio bytes, process them immediately
    if (widget.initialAudioBytes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processAudioMessage(widget.initialAudioBytes!);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
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
      _messages.add(ChatMessage(
        text: '🎤 Voice message',
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isProcessing = true;
      _statusMessage = 'Transcribing audio...';
    });

    _scrollToBottom();

    try {
      final model = SettingsService.instance.aiModel.value;
      String aiResponse = '';

      await ref.read(apiServiceProvider).sendAudioStream(
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
              _messages.add(ChatMessage(
                text: aiResponse,
                isUser: false,
                timestamp: DateTime.now(),
              ));
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
            LoggingService.logger.warning('Failed to sync after audio AI: $e');
          }
        },
        onStatus: (status) {
          setState(() {
            _statusMessage = status;
          });
        },
      );
    } catch (e) {
      LoggingService.logger.severe('Error processing audio: $e');
      setState(() {
        _messages.add(ChatMessage(
          text: 'Error: Failed to process audio',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isProcessing = false;
        _statusMessage = null;
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty || _isProcessing) return;

    final userMessage = _textController.text.trim();
    _textController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isProcessing = true;
      _statusMessage = 'Initializing...';
    });

    _scrollToBottom();

    try {
      final model = SettingsService.instance.aiModel.value;
      String aiResponse = '';

      await ref.read(apiServiceProvider).sendTextAIStream(
        userMessage,
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
              _messages.add(ChatMessage(
                text: aiResponse,
                isUser: false,
                timestamp: DateTime.now(),
              ));
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
            LoggingService.logger.warning('Failed to sync after text AI: $e');
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
        _messages.add(ChatMessage(
          text: 'Error: Failed to get AI response',
          isUser: false,
          timestamp: DateTime.now(),
        ));
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
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
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
              child: SelectableText(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
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
    if (!_isProcessing || _statusMessage == null) return const SizedBox.shrink();

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat'),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withAlpha(51),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !_isProcessing,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isProcessing ? null : _sendMessage,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
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
}