import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/ws_message_type.dart';
import 'logging_service.dart';

/// Callback for handling WebSocket messages
typedef WSMessageCallback = void Function(WSMessageType type, Map<String, dynamic> data);

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
