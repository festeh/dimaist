import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/recording_dialog.dart';

class ChatInputWidget extends StatefulWidget {
  final Function(String, {List<String>? images}) onSendMessage;
  final VoidCallback? onVoicePressed;
  final Function(List<int>)? onAudioRecorded;
  final bool isProcessing;

  const ChatInputWidget({
    super.key,
    required this.onSendMessage,
    this.onVoicePressed,
    this.onAudioRecorded,
    this.isProcessing = false,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  bool _hasText = false;
  Uint8List? _attachedImageBytes;
  String? _attachedImageDataUri;

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

  bool get _canSend => (_hasText || _attachedImageBytes != null) && !widget.isProcessing;

  void _sendMessage() {
    final text = _textController.text.trim();
    if (!_canSend) return;

    List<String>? images;
    if (_attachedImageDataUri != null) {
      images = [_attachedImageDataUri!];
    }

    widget.onSendMessage(text, images: images);
    _textController.value = TextEditingValue.empty;
    _focusNode.unfocus();
    setState(() {
      _hasText = false;
      _attachedImageBytes = null;
      _attachedImageDataUri = null;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final ext = picked.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

    setState(() {
      _attachedImageBytes = bytes;
      _attachedImageDataUri = dataUri;
    });
  }

  void _showImageSourceSheet() {
    if (Platform.isLinux) {
      // Desktop: just open file picker (gallery)
      _pickImage(ImageSource.gallery);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _attachedImageBytes = null;
      _attachedImageDataUri = null;
    });
  }

  void _showVoiceDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          RecordingDialog(onAudioRecorded: widget.onAudioRecorded),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image preview
              if (_attachedImageBytes != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _attachedImageBytes!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: _removeImage,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Theme.of(context).colorScheme.onError,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Input row
              Row(
                children: [
                  // Image button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.isProcessing ? null : _showImageSourceSheet,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: PhosphorIcon(
                          PhosphorIcons.image(),
                          color: widget.isProcessing
                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                              : Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

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
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: PhosphorIcon(
                          PhosphorIcons.microphone(),
                          color: widget.isProcessing
                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                              : Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Text input field
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (KeyEvent event) {
                          if (Platform.isLinux &&
                              event is KeyDownEvent &&
                              HardwareKeyboard.instance.isControlPressed &&
                              event.logicalKey == LogicalKeyboardKey.enter) {
                            _sendMessage();
                          }
                        },
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          enabled: !widget.isProcessing,
                          decoration: InputDecoration(
                            hintText: widget.isProcessing ? 'Processing...' : null,
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          textInputAction: TextInputAction.newline,
                          minLines: 1,
                          maxLines: 5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Send button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _canSend ? _sendMessage : null,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _canSend
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: PhosphorIcon(
                          PhosphorIcons.paperPlaneRight(),
                          color: _canSend
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
