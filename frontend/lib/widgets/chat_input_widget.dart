import 'package:flutter/material.dart';
import '../widgets/recording_dialog.dart';

class ChatInputWidget extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback? onVoicePressed;
  final VoidCallback? onAddPressed;
  final bool isProcessing;

  const ChatInputWidget({
    super.key,
    required this.onSendMessage,
    this.onVoicePressed,
    this.onAddPressed,
    this.isProcessing = false,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
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

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && !widget.isProcessing) {
      widget.onSendMessage(text);
      _textController.clear();
      setState(() {
        _hasText = false;
      });
    }
  }

  void _showVoiceDialog() {
    showDialog(context: context, builder: (context) => const RecordingDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Add button
            if (widget.onAddPressed != null) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.isProcessing ? null : widget.onAddPressed,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.add,
                      color: widget.isProcessing 
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                          : Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16), // Space between add and voice
            ],
            
            // Voice button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isProcessing
                    ? null
                    : (widget.onVoicePressed ?? _showVoiceDialog),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.mic,
                    color: widget.isProcessing
                        ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.4)
                        : Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16), // Space between voice and text input
            // Text input field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  enabled: !widget.isProcessing,
                  decoration: InputDecoration(
                    hintText: widget.isProcessing
                        ? 'Processing...'
                        : 'Ask AI to help with tasks...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  maxLines: 1,
                ),
              ),
            ),

            const SizedBox(width: 16), // Space between text input and send
            // Send button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _hasText && !widget.isProcessing ? _sendMessage : null,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _hasText && !widget.isProcessing
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: widget.isProcessing
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        )
                      : Icon(
                          Icons.send,
                          color: _hasText
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
