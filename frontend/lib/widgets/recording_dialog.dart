import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:record/record.dart';
import '../screens/ai_chat_screen.dart';

class RecordingDialog extends ConsumerStatefulWidget {
  final Function(List<int>)? onAudioRecorded;

  const RecordingDialog({super.key, this.onAudioRecorded});

  @override
  ConsumerState<RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends ConsumerState<RecordingDialog>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _audioPath;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _startRecording();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _requestPermissions();
    if (hasPermission) {
      // Linux doesn't support pcm16bits, use WAV instead
      final encoder = Platform.isLinux ? AudioEncoder.wav : AudioEncoder.pcm16bits;
      final extension = Platform.isLinux ? 'wav' : 'pcm';
      final config = RecordConfig(
        encoder: encoder,
        numChannels: 1,
        sampleRate: 16000,
        bitRate: 256000,
        noiseSuppress: true,
      );
      final path = '${Directory.systemTemp.path}/temp.$extension';
      await _recorder.start(config, path: path);
      setState(() {
        _isRecording = true;
      });
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isLinux) {
      return true;
    }
    var status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _audioPath = path;
    });

    if (_audioPath != null && mounted) {
      final navigator = Navigator.of(context);
      final file = File(_audioPath!);
      final bytes = await file.readAsBytes();

      if (!mounted) return;
      navigator.pop(); // Close recording dialog

      if (widget.onAudioRecorded != null) {
        // Use callback if provided (for in-chat recording)
        widget.onAudioRecorded!(bytes);
      } else {
        // Navigate to new chat screen (for recording from elsewhere)
        navigator.push(
          MaterialPageRoute(
            builder: (context) => AiChatScreen(initialAudioBytes: bytes),
          ),
        );
      }
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isRecording
            ? 'Recording...'
            : _isProcessing
            ? 'Processing...'
            : 'Done',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRecording)
            ScaleTransition(
              scale: _scaleAnimation,
              child: PhosphorIcon(PhosphorIcons.microphone(), size: 50),
            )
          else if (_isProcessing)
            ScaleTransition(
              scale: _scaleAnimation,
              child: PhosphorIcon(PhosphorIcons.hourglass(), size: 50),
            )
          else
            const SizedBox.shrink(),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isRecording ? _stopRecording : null,
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}
