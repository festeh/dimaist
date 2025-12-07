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
class AiWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _logger = LoggingService.logger;

  /// Connect to the WebSocket server
  void connect(String baseUrl) {
    final wsUrl = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    final uri = Uri.parse('$wsUrl/ai');
    _logger.info('Connecting to WebSocket: $uri');
    _channel = WebSocketChannel.connect(uri);
  }

  /// Start a conversation with the AI
  void startConversation({
    required List<Map<String, dynamic>> messages,
    required String provider,
    required String model,
    required bool includeCompleted,
    required WSMessageCallback onMessage,
    required void Function() onDone,
    required void Function(String) onError,
  }) {
    if (_channel == null) {
      onError('WebSocket not connected');
      return;
    }

    _logger.info('Starting AI conversation with provider: $provider, model: $model, includeCompleted: $includeCompleted');

    // Send start message
    final startMessage = {
      'type': WSMessageType.start.toJson(),
      'messages': messages,
      'provider': provider,
      'model': model,
      'include_completed': includeCompleted,
    };
    _channel!.sink.add(jsonEncode(startMessage));

    // Listen for responses
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

          onMessage(type, msg);

          // Check for terminal messages
          if (type == WSMessageType.finalResponse ||
              type == WSMessageType.cancelled ||
              type == WSMessageType.error) {
            onDone();
          }
        } catch (e) {
          _logger.severe('Error parsing WebSocket message: $e, data: $data');
          onError('Failed to parse message: $e');
        }
      },
      onError: (error) {
        _logger.severe('WebSocket error: $error');
        onError(error.toString());
      },
      onDone: () {
        _logger.info('WebSocket connection closed');
        onDone();
      },
    );
  }

  /// Send confirmation for a pending tool
  void confirm(Map<String, dynamic>? arguments) {
    if (_channel == null) {
      _logger.warning('Cannot confirm: WebSocket not connected');
      return;
    }

    final message = {
      'type': WSMessageType.confirm.toJson(),
      if (arguments != null) 'arguments': arguments,
    };
    _logger.info('Sending confirmation', arguments);
    _channel!.sink.add(jsonEncode(message));
  }

  /// Reject a pending tool
  void reject() {
    if (_channel == null) {
      _logger.warning('Cannot reject: WebSocket not connected');
      return;
    }

    final message = {'type': WSMessageType.reject.toJson()};
    _logger.info('Sending rejection');
    _channel!.sink.add(jsonEncode(message));
  }

  /// Send batch confirmation for multiple tools
  void batchConfirm(List<ToolStatus> statuses, {String? newMessage}) {
    if (_channel == null) {
      _logger.warning('Cannot batch confirm: WebSocket not connected');
      return;
    }

    final message = <String, dynamic>{
      'type': WSMessageType.batchConfirm.toJson(),
      'statuses': statuses.map((s) => s.toJson()).toList(),
    };
    if (newMessage != null && newMessage.isNotEmpty) {
      message['new_message'] = newMessage;
    }
    _logger.info('Sending batch confirmation', statuses);
    _channel!.sink.add(jsonEncode(message));
  }

  // --- Parallel mode methods ---

  /// Start a parallel conversation with multiple models
  void startParallelConversation({
    required List<Map<String, dynamic>> messages,
    required List<TargetSpec> targets,
    required bool includeCompleted,
    required WSMessageCallback onMessage,
    required void Function() onDone,
    required void Function(String) onError,
  }) {
    if (_channel == null) {
      onError('WebSocket not connected');
      return;
    }

    _logger.info('Starting parallel AI conversation with ${targets.length} models');

    // Send start message with multiple targets
    final startMessage = {
      'type': WSMessageType.start.toJson(),
      'messages': messages,
      'targets': targets.map((t) => t.toJson()).toList(),
      'include_completed': includeCompleted,
    };
    _channel!.sink.add(jsonEncode(startMessage));

    // Listen for responses
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

          onMessage(type, msg);

          // In parallel mode, allComplete or error ends the initial phase
          // but we stay connected for user actions
          if (type == WSMessageType.error) {
            onDone();
          }
        } catch (e) {
          _logger.severe('Error parsing WebSocket message: $e, data: $data');
          onError('Failed to parse message: $e');
        }
      },
      onError: (error) {
        _logger.severe('WebSocket error: $error');
        onError(error.toString());
      },
      onDone: () {
        _logger.info('WebSocket connection closed');
        onDone();
      },
    );
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

  /// Send batch confirmation for a specific model (parallel mode)
  void batchConfirmForModel(
    String targetId,
    List<ToolStatus> statuses, {
    String? newMessage,
  }) {
    if (_channel == null) {
      _logger.warning('Cannot batch confirm: WebSocket not connected');
      return;
    }

    final message = <String, dynamic>{
      'type': WSMessageType.batchConfirm.toJson(),
      'target_id': targetId,
      'statuses': statuses.map((s) => s.toJson()).toList(),
    };
    if (newMessage != null && newMessage.isNotEmpty) {
      message['new_message'] = newMessage;
    }
    _logger.info('Sending batch confirmation for model: $targetId');
    _channel!.sink.add(jsonEncode(message));
  }

  /// Send a new message in parallel mode (continues parallel to all models)
  void sendParallelMessage(List<Map<String, dynamic>> messages) {
    if (_channel == null) {
      _logger.warning('Cannot send message: WebSocket not connected');
      return;
    }

    final message = {
      'type': WSMessageType.start.toJson(),
      'messages': messages,
    };
    _logger.info('Sending new message in parallel mode');
    _channel!.sink.add(jsonEncode(message));
  }

  /// Close the WebSocket connection
  void close() {
    _logger.info('Closing WebSocket connection');
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  /// Check if connected
  bool get isConnected => _channel != null;
}
