import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../models/ai_model.dart';
import '../providers/task_provider.dart';
import '../services/logging_service.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  String _selectedModel = AiModel.defaultModel.value;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _selectedModel = SettingsService.instance.aiModel.value;
  }

  Future<void> _triggerSync() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      await ref.read(taskProvider.notifier).syncData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      LoggingService.logger.warning('Failed to sync: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy),
                const SizedBox(width: 16),
                const Text(
                  'AI Model:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedModel,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedModel = newValue;
                        });
                        final model = AiModel.fromString(newValue);
                        if (model != null) {
                          SettingsService.instance.setAiModel(model);
                        }
                      }
                    },
                    items: AiModel.allValues.map<DropdownMenuItem<String>>((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.sync),
                const SizedBox(width: 16),
                const Text(
                  'Data Sync:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSyncing ? null : _triggerSync,
                    child: _isSyncing
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Syncing...'),
                            ],
                          )
                        : const Text('Sync Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
