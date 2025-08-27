import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/providers.dart';
import '../services/settings_service.dart';
import '../services/logging_service.dart';

class TextAiDialog extends ConsumerStatefulWidget {
  const TextAiDialog({super.key});

  @override
  ConsumerState<TextAiDialog> createState() => _TextAiDialogState();
}

class _TextAiDialogState extends ConsumerState<TextAiDialog> {
  final TextEditingController _textController = TextEditingController();
  bool _isProcessing = false;
  String? _response;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendTextAI() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _response = '';
    });

    try {
      final model = SettingsService.instance.aiModel.value;
      await ref.read(apiServiceProvider).sendTextAIStream(
        _textController.text.trim(),
        model,
        (chunk) {
          setState(() {
            _response = (_response ?? '') + chunk;
          });
        },
        () {
          setState(() {
            _isProcessing = false;
          });
        },
      );
    } catch (e) {
      LoggingService.logger.severe('Error sending text AI request: $e');
      setState(() {
        _response = 'Error: Failed to get AI response';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Text AI'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Enter your text here...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (_response != null && _response!.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Response:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(_response!),
                    if (_isProcessing) ...[
                      const SizedBox(height: 8),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isProcessing) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: _textController.text.trim().isEmpty ? null : _sendTextAI,
            child: const Text('Send'),
          ),
        ],
      ],
    );
  }
}