/// WebSocket message types for AI chat communication
enum WSMessageType {
  // Client -> Server message types
  start,
  confirm,
  reject,

  // Server -> Client message types
  thinking,
  toolPending,
  toolResult,
  finalResponse,
  cancelled,
  error;

  /// Convert enum to snake_case string for JSON
  String toJson() {
    switch (this) {
      case WSMessageType.start:
        return 'start';
      case WSMessageType.confirm:
        return 'confirm';
      case WSMessageType.reject:
        return 'reject';
      case WSMessageType.thinking:
        return 'thinking';
      case WSMessageType.toolPending:
        return 'tool_pending';
      case WSMessageType.toolResult:
        return 'tool_result';
      case WSMessageType.finalResponse:
        return 'final_response';
      case WSMessageType.cancelled:
        return 'cancelled';
      case WSMessageType.error:
        return 'error';
    }
  }

  /// Parse from JSON snake_case string
  static WSMessageType fromJson(String value) {
    switch (value) {
      case 'start':
        return WSMessageType.start;
      case 'confirm':
        return WSMessageType.confirm;
      case 'reject':
        return WSMessageType.reject;
      case 'thinking':
        return WSMessageType.thinking;
      case 'tool_pending':
        return WSMessageType.toolPending;
      case 'tool_result':
        return WSMessageType.toolResult;
      case 'final_response':
        return WSMessageType.finalResponse;
      case 'cancelled':
        return WSMessageType.cancelled;
      case 'error':
        return WSMessageType.error;
      default:
        throw ArgumentError('Unknown message type: $value');
    }
  }
}
