import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../repositories/providers.dart';
import '../services/settings_service.dart';
import '../services/logging_service.dart';
import '../providers/task_provider.dart';
import '../widgets/chat_input_widget.dart';

enum MessageType {
  normal,
  toolCall,
  toolResult,
}

class ChatMessage {
  final String text;
  final String role; // 'user', 'assistant', 'system'
  final DateTime timestamp;
  final MessageType type;
  final Map<String, dynamic>? metadata; // for tool details

  ChatMessage({
    required this.text,
    required this.role,
    required this.timestamp,
    this.type = MessageType.normal,
    this.metadata,
  });

  // Helper getter for backward compatibility
  bool get isUser => role == 'user';

  // Convert to API format
  Map<String, dynamic> toApiFormat() {
    final apiMessage = {
      'role': role,
      'content': text,
    };
    
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

  List<Map<String, dynamic>> _buildMessagesFromHistory() {
    // Only include normal user/assistant messages for API context
    // Tool calls and results are UI indicators, not conversation messages
    return _messages
        .where((msg) => msg.type == MessageType.normal)
        .map((msg) => msg.toApiFormat())
        .toList();
  }

  void _addToolMessage(String text, MessageType type, {Map<String, dynamic>? metadata}) {
    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          role: 'assistant',
          timestamp: DateTime.now(),
          type: type,
          metadata: metadata,
        ),
      );
    });
    _scrollToBottom();
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
      _statusMessage = 'Transcribing audio...';
    });

    _scrollToBottom();

    try {
      final model = SettingsService.instance.aiModel.value;
      String aiResponse = '';
      bool transcriptionReceived = false;

      // Build messages history for context
      final previousMessages = _buildMessagesFromHistory();
      
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
                    role: 'assistant',
                    timestamp: _messages.last.timestamp,
                  );
                } else {
                  _messages.add(
                    ChatMessage(
                      text: aiResponse,
                      role: 'assistant',
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
                    role: 'user',
                    timestamp: _messages.last.timestamp,
                  );
                  transcriptionReceived = true;
                });
                _scrollToBottom();
              }
            },
            onToolCall: (toolCall) {
              _addToolMessage(toolCall, MessageType.toolCall);
            },
            onToolResult: (toolResult) {
              _addToolMessage(toolResult, MessageType.toolResult);
            },
            previousMessages: previousMessages,
          );
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
        ChatMessage(text: message, role: 'user', timestamp: DateTime.now()),
      );
      _isProcessing = true;
      _statusMessage = 'Initializing...';
    });

    _scrollToBottom();

    try {
      final model = SettingsService.instance.aiModel.value;
      String aiResponse = '';

      // Build complete messages array including the new user message
      final messagesHistory = _buildMessagesFromHistory();
      // The new user message is already added to _messages, so we need to include it
      final allMessages = messagesHistory + [{
        'role': 'user',
        'content': message,
      }];

      await ref
          .read(apiServiceProvider)
          .sendTextAIStream(
            allMessages,
            model,
            (chunk) {
              setState(() {
                aiResponse += chunk;
                if (_messages.isNotEmpty && !_messages.last.isUser) {
                  _messages.last = ChatMessage(
                    text: aiResponse,
                    role: 'assistant',
                    timestamp: _messages.last.timestamp,
                  );
                } else {
                  _messages.add(
                    ChatMessage(
                      text: aiResponse,
                      role: 'assistant',
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
            onToolCall: (toolCall) {
              _addToolMessage(toolCall, MessageType.toolCall);
            },
            onToolResult: (toolResult) {
              _addToolMessage(toolResult, MessageType.toolResult);
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
        _statusMessage = null;
      });
      _scrollToBottom();
    }
  }

  Widget _buildMessage(ChatMessage message) {
    // Handle tool call and tool result messages
    if (message.type == MessageType.toolCall || message.type == MessageType.toolResult) {
      return _buildToolMessage(message);
    }

    // User messages - use card style similar to AI messages but right-aligned
    if (message.isUser) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300), // Limit max width
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple[200]!,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 18,
                          color: Colors.purple[700],
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'You',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.purple[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      message.text,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 13,
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

    // AI responses - use card style similar to tool messages
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 40), // Indent to align with other AI messages
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue[200]!,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.smart_toy,
                        size: 18,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Response',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 13,
                      ),
                      h1: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      h3: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      h4: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      h5: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      h6: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      listBullet: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 13,
                      ),
                      em: TextStyle(
                        color: Colors.grey[800],
                        fontStyle: FontStyle.italic,
                      ),
                      strong: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.bold,
                      ),
                      a: TextStyle(
                        color: Colors.blue[600],
                        decoration: TextDecoration.underline,
                      ),
                      blockquote: TextStyle(
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                      tableHead: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.bold,
                      ),
                      tableBody: TextStyle(
                        color: Colors.grey[800],
                      ),
                      code: TextStyle(
                        backgroundColor: Colors.grey[200],
                        color: Colors.grey[800],
                        fontFamily: 'monospace',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
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

  Widget _buildToolMessage(ChatMessage message) {
    final isToolCall = message.type == MessageType.toolCall;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 40), // Indent to align with AI messages
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isToolCall 
                    ? Colors.orange[50]
                    : Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToolCall 
                      ? Colors.orange[200]!
                      : Colors.green[200]!,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isToolCall ? Icons.build : Icons.check_circle_outline,
                        size: 18,
                        color: isToolCall ? Colors.orange[700] : Colors.green[700],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isToolCall ? 'Tool Call' : 'Tool Result',
                          style: TextStyle(
                            fontSize: 14,
                            color: isToolCall ? Colors.orange[700] : Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                      fontFamily: 'monospace',
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
