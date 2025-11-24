import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../models/ai_model.dart';
import '../providers/task_provider.dart';
import '../providers/theme_provider.dart';
import '../services/logging_service.dart';
import '../config/design_tokens.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  String _selectedModel = AiModel.defaultModel.value;
  bool _isSyncing = false;

  String _getCondensedModelName(String fullPath) {
    final parts = fullPath.split('/');
    if (parts.length >= 3) {
      return '${parts.first.substring(0, 1)}/${parts.last}';
    }
    return fullPath;
  }

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

  Widget _buildThemeSelector() {
    final currentTheme = ref.watch(themeProvider);
    final colors = AppColors.forTheme(currentTheme);

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: AppThemeMode.values.map((mode) {
        final isSelected = mode == currentTheme;
        final modeColors = AppColors.forTheme(mode);

        return Tooltip(
          message: mode.description,
          child: InkWell(
            onTap: () => ref.read(themeProvider.notifier).setTheme(mode),
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: isSelected ? colors.primary.withValues(alpha: 0.2) : null,
                border: Border.all(
                  color: isSelected ? colors.primary : colors.border,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: modeColors.primary,
                      borderRadius: BorderRadius.circular(Radii.xs),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    mode.displayName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? colors.primary : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
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
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedModel,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      fillColor: Theme.of(context).colorScheme.surface,
                      filled: true,
                    ),
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
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
                        child: Text(
                          _getCondensedModelName(value),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.palette),
                const SizedBox(width: 16),
                const Text(
                  'Theme:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildThemeSelector(),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
