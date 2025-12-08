/// WebSocket message types for AI chat communication
enum WSMessageType {
  // Client -> Server message types
  start,
  confirm,
  reject,
  toolConfirm, // Single tool confirmation
  continueMsg, // Continue with new message (remaining tools rejected)

  // Server -> Client message types
  thinking,
  toolPending, // Single tool (legacy)
  toolsPending, // Batch tools
  toolResult,
  finalResponse,
  cancelled,
  error,

  // Parallel mode message types
  modelResponse, // Single model responded
  modelError, // Single model errored
  allComplete, // All models finished
  selectModel; // User selected winning model

  /// Convert enum to snake_case string for JSON
  String toJson() {
    switch (this) {
      case WSMessageType.start:
        return 'start';
      case WSMessageType.confirm:
        return 'confirm';
      case WSMessageType.reject:
        return 'reject';
      case WSMessageType.toolConfirm:
        return 'tool_confirm';
      case WSMessageType.continueMsg:
        return 'continue';
      case WSMessageType.thinking:
        return 'thinking';
      case WSMessageType.toolPending:
        return 'tool_pending';
      case WSMessageType.toolsPending:
        return 'tools_pending';
      case WSMessageType.toolResult:
        return 'tool_result';
      case WSMessageType.finalResponse:
        return 'final_response';
      case WSMessageType.cancelled:
        return 'cancelled';
      case WSMessageType.error:
        return 'error';
      case WSMessageType.modelResponse:
        return 'model_response';
      case WSMessageType.modelError:
        return 'model_error';
      case WSMessageType.allComplete:
        return 'all_complete';
      case WSMessageType.selectModel:
        return 'select_model';
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
      case 'tool_confirm':
        return WSMessageType.toolConfirm;
      case 'continue':
        return WSMessageType.continueMsg;
      case 'thinking':
        return WSMessageType.thinking;
      case 'tool_pending':
        return WSMessageType.toolPending;
      case 'tools_pending':
        return WSMessageType.toolsPending;
      case 'tool_result':
        return WSMessageType.toolResult;
      case 'final_response':
        return WSMessageType.finalResponse;
      case 'cancelled':
        return WSMessageType.cancelled;
      case 'error':
        return WSMessageType.error;
      case 'model_response':
        return WSMessageType.modelResponse;
      case 'model_error':
        return WSMessageType.modelError;
      case 'all_complete':
        return WSMessageType.allComplete;
      case 'select_model':
        return WSMessageType.selectModel;
      default:
        throw ArgumentError('Unknown message type: $value');
    }
  }
}

/// Represents a pending tool call from the server
class PendingToolCall {
  final String toolCallId;
  final String name;
  final Map<String, dynamic> arguments;

  PendingToolCall({
    required this.toolCallId,
    required this.name,
    required this.arguments,
  });

  factory PendingToolCall.fromJson(Map<String, dynamic> json) {
    return PendingToolCall(
      toolCallId: json['tool_call_id'] as String,
      name: json['name'] as String,
      arguments: Map<String, dynamic>.from(json['arguments'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tool_call_id': toolCallId,
      'name': name,
      'arguments': arguments,
    };
  }
}

/// Status of a tool in batch confirmation
class ToolStatus {
  final String toolCallId;
  final String status; // "confirmed" or "rejected"
  final Map<String, dynamic>? arguments; // Modified args if confirmed

  ToolStatus({
    required this.toolCallId,
    required this.status,
    this.arguments,
  });

  factory ToolStatus.fromJson(Map<String, dynamic> json) {
    return ToolStatus(
      toolCallId: json['tool_call_id'] as String,
      status: json['status'] as String,
      arguments: json['arguments'] != null
          ? Map<String, dynamic>.from(json['arguments'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'tool_call_id': toolCallId,
      'status': status,
    };
    if (arguments != null) {
      map['arguments'] = arguments;
    }
    return map;
  }
}
