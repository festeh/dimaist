import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/ws_message_type.dart';
import 'logging_service.dart';

/// Callback for handling WebSocket messages
typedef WSMessageCallback = void Function(WSMessageType type, Map<String, dynamic> data);

/// Target specification for parallel requests
class TargetSpec {
  final String provider;
  final String model;

  const TargetSpec({required this.provider, required this.model});

  /// Unique identifier for this target
  String get id => '$provider:$model';

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'model': model,
      };
}

/// Service for AI chat communication via WebSocket
/// Connection stays open for entire chat session.
class AiWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _logger = LoggingService.logger;

  // Callbacks set once at connect time
  WSMessageCallback? _onMessage;
  void Function()? _onConnectionClosed;
  void Function(String)? _onError;

  /// Connect to the WebSocket server and set up message listener
  void connect({
    required String baseUrl,
    required WSMessageCallback onMessage,
    required void Function() onConnectionClosed,
    required void Function(String) onError,
  }) {
    if (_channel != null) {
      _logger.warning('Already connected, closing existing connection');
      close();
    }

    _onMessage = onMessage;
    _onConnectionClosed = onConnectionClosed;
    _onError = onError;

    final wsUrl = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    final uri = Uri.parse('$wsUrl/ai');
    _logger.info('Connecting to WebSocket: $uri');
    _channel = WebSocketChannel.connect(uri);

    // Set up message listener once
    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          final typeStr = msg['type'] as String?;
          if (typeStr == null) {
            _logger.warning('Received message without type: $msg');
            return;
          }

          final type = WSMessageType.fromJson(typeStr);
          _logger.fine('Received WebSocket message: $type');

          _onMessage?.call(type, msg);
        } catch (e) {
          _logger.severe('Error parsing WebSocket message: $e, data: $data');
          _onError?.call('Failed to parse message: $e');
        }
      },
      onError: (error) {
        _logger.severe('WebSocket error: $error');
        _onError?.call(error.toString());
      },
      onDone: () {
        _logger.info('WebSocket connection closed');
        _onConnectionClosed?.call();
      },
    );
  }

  /// Send start message (first message of conversation)
  void sendStart({
    required String message,
    required List<TargetSpec> targets,
    required bool includeCompleted,
    int? currentProjectId,
  }) {
    if (_channel == null) {
      _logger.warning('Cannot send start: WebSocket not connected');
      return;
    }

    _logger.info('Sending start message with ${targets.length} targets, project: $currentProjectId');

    final startMessage = {
      'type': WSMessageType.start.toJson(),
      'messages': [{'role': 'user', 'content': message}],
      'targets': targets.map((t) => t.toJson()).toList(),
      'include_completed': includeCompleted,
      if (currentProjectId != null) 'current_project_id': currentProjectId,
    };
    _channel!.sink.add(jsonEncode(startMessage));
  }

  /// Send continue message (subsequent messages)
  void sendContinue(String message) {
    if (_channel == null) {
      _logger.warning('Cannot send continue: WebSocket not connected');
      return;
    }

    _logger.info('Sending continue message');

    final continueMessage = {
      'type': WSMessageType.continueMsg.toJson(),
      'new_message': message,
    };
    _channel!.sink.add(jsonEncode(continueMessage));
  }

  /// Confirm a single tool for execution
  void confirmTool(String targetId, String toolCallId, Map<String, dynamic>? arguments) {
    if (_channel == null) {
      _logger.warning('Cannot confirm tool: WebSocket not connected');
      return;
    }

    final message = <String, dynamic>{
      'type': WSMessageType.toolConfirm.toJson(),
      'target_id': targetId,
      'tool_call_id': toolCallId,
    };
    if (arguments != null) {
      message['arguments'] = arguments;
    }
    _logger.info('Confirming tool: $toolCallId for target: $targetId');
    _channel!.sink.add(jsonEncode(message));
  }

  /// Select a winning model (when user engages with its tools)
  void selectModel(String targetId) {
    if (_channel == null) {
      _logger.warning('Cannot select model: WebSocket not connected');
      return;
    }

    final message = {
      'type': WSMessageType.selectModel.toJson(),
      'target_id': targetId,
    };
    _logger.info('Selecting model: $targetId');
    _channel!.sink.add(jsonEncode(message));
  }

  /// Close the WebSocket connection
  void close() {
    _logger.info('Closing WebSocket connection');
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _onMessage = null;
    _onConnectionClosed = null;
    _onError = null;
  }

  /// Check if connected
  bool get isConnected => _channel != null;
}
