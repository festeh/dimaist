import 'dart:async';
import 'package:dimaist/services/logging_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../repositories/providers.dart';
import '../services/settings_service.dart';
import '../providers/task_provider.dart';

class RecordingDialog extends ConsumerStatefulWidget {
  const RecordingDialog({super.key});

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
      const encoder = AudioEncoder.wav;
      const config = RecordConfig(
        encoder: encoder,
        numChannels: 1,
        sampleRate: 16000,
        bitRate: 256000,
        noiseSuppress: true,
      );
      final path = '${Directory.systemTemp.path}/temp.wav';
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
    if (_audioPath != null) {
      try {
        final file = File(_audioPath!);
        final bytes = await file.readAsBytes();
        final model = SettingsService.instance.aiModel.value;
        await ref.read(apiServiceProvider).sendAudio(bytes, model);
      } catch (e) {
        LoggingService.logger.severe('Error sending audio: $e');
      } finally {
        // Trigger sync after AI flow completes
        try {
          await ref.read(taskProvider.notifier).syncData();
        } catch (e) {
          LoggingService.logger.warning('Failed to sync after audio AI: $e');
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
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
              child: const Icon(Icons.mic, size: 50),
            )
          else if (_isProcessing)
            ScaleTransition(
              scale: _scaleAnimation,
              child: const Icon(Icons.hourglass_empty, size: 50),
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
