import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/font_provider.dart';
import '../providers/ai_model_provider.dart';
import '../providers/parallel_ai_provider.dart';
import '../providers/asr_language_provider.dart';
import '../providers/include_completed_provider.dart';
import '../services/logging_service.dart';
import '../config/design_tokens.dart';
import 'model_list_dialog.dart';
import 'model_display.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  bool _isSyncing = false;

  Future<void> _triggerSync() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      // Full resync: clear local DB and fetch everything from server
      await ref.read(taskProvider.notifier).fullResync();
      ref.invalidate(projectProvider);
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

  void _openModelManager() {
    showDialog(
      context: context,
      builder: (context) => const ModelListDialog(),
    );
  }

  void _openThemeSelector() {
    final currentTheme = ref.read(themeProvider);
    showDialog(
      context: context,
      builder: (context) => _SelectionDialog<AppThemeMode>(
        title: 'Select Theme',
        values: AppThemeMode.values,
        currentValue: currentTheme,
        onSelect: (mode) => ref.read(themeProvider.notifier).setTheme(mode),
        itemBuilder: (mode, isSelected, colors) => Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.forTheme(mode).primary,
                borderRadius: BorderRadius.circular(Radii.xs),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Text(
              mode.displayName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFontSelector() {
    final currentFont = ref.read(fontProvider);
    showDialog(
      context: context,
      builder: (context) => _SelectionDialog<AppFont>(
        title: 'Select Font',
        values: AppFont.values,
        currentValue: currentFont,
        onSelect: (font) => ref.read(fontProvider.notifier).setFont(font),
        itemBuilder: (font, isSelected, colors) => Text(
          font.displayName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _openAsrLanguageSelector() {
    final currentLanguage = ref.read(asrLanguageProvider);
    showDialog(
      context: context,
      builder: (context) => _SelectionDialog<AsrLanguage>(
        title: 'Select ASR Language',
        values: AsrLanguage.values,
        currentValue: currentLanguage,
        onSelect: (lang) => ref.read(asrLanguageProvider.notifier).setLanguage(lang),
        itemBuilder: (lang, isSelected, colors) => Text(
          lang.displayName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _toggleIncludeCompleted() {
    final current = ref.read(includeCompletedInAiProvider);
    ref.read(includeCompletedInAiProvider.notifier).setIncludeCompleted(!current);
  }

  Widget _buildSettingRow({
    required PhosphorIconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          children: [
            PhosphorIcon(icon, size: Sizes.iconMd),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: Spacing.xs),
            PhosphorIcon(
              PhosphorIcons.caretRight(),
              size: Sizes.iconSm,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelState = ref.watch(aiModelProvider);
    final parallelState = ref.watch(parallelAiProvider);
    // Get first selected model for display (null if none selected)
    final selectedIds = parallelState.selectedModelIds;
    final selectedModel = selectedIds.isNotEmpty
        ? modelState.models.where((m) => m.id == selectedIds.first).firstOrNull
        : null;
    final currentTheme = ref.watch(themeProvider);
    final currentFont = ref.watch(fontProvider);
    final currentLanguage = ref.watch(asrLanguageProvider);
    final includeCompleted = ref.watch(includeCompletedInAiProvider);

    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI Model
            InkWell(
              onTap: _openModelManager,
              borderRadius: BorderRadius.circular(Radii.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                child: Row(
                  children: [
                    PhosphorIcon(PhosphorIcons.robot(), size: Sizes.iconMd),
                    const SizedBox(width: Spacing.md),
                    const Expanded(
                      child: Text(
                        'AI Model',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Flexible(
                      child: selectedModel != null
                          ? ModelDisplay(model: selectedModel)
                          : const Text('None selected'),
                    ),
                    const SizedBox(width: Spacing.xs),
                    PhosphorIcon(
                      PhosphorIcons.caretRight(),
                      size: Sizes.iconSm,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),

            // Theme
            _buildSettingRow(
              icon: PhosphorIcons.palette(),
              label: 'Theme',
              value: currentTheme.displayName,
              onTap: _openThemeSelector,
            ),

            // Font
            _buildSettingRow(
              icon: PhosphorIcons.textAa(),
              label: 'Font',
              value: currentFont.displayName,
              onTap: _openFontSelector,
            ),

            // ASR Language
            _buildSettingRow(
              icon: PhosphorIcons.globe(),
              label: 'ASR Language',
              value: currentLanguage.displayName,
              onTap: _openAsrLanguageSelector,
            ),

            // Include completed tasks in AI
            _buildSettingRow(
              icon: PhosphorIcons.checkCircle(),
              label: 'Include completed in AI',
              value: includeCompleted ? 'Yes' : 'No',
              onTap: _toggleIncludeCompleted,
            ),

            const SizedBox(height: Spacing.md),
            const Divider(),
            const SizedBox(height: Spacing.sm),

            // Sync button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSyncing ? null : _triggerSync,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : PhosphorIcon(PhosphorIcons.arrowsClockwise(), size: Sizes.iconSm),
                label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
              ),
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

/// Generic selection dialog for settings options
class _SelectionDialog<T> extends StatelessWidget {
  final String title;
  final List<T> values;
  final T currentValue;
  final void Function(T) onSelect;
  final Widget Function(T value, bool isSelected, ColorScheme colors) itemBuilder;

  const _SelectionDialog({
    required this.title,
    required this.values,
    required this.currentValue,
    required this.onSelect,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 250,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: values.map((value) {
            final isSelected = value == currentValue;
            return InkWell(
              onTap: () {
                onSelect(value);
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(Radii.sm),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.md,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary.withValues(alpha: 0.1) : null,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Row(
                  children: [
                    Expanded(child: itemBuilder(value, isSelected, colors)),
                    if (isSelected)
                      PhosphorIcon(
                        PhosphorIcons.check(),
                        size: Sizes.iconSm,
                        color: colors.primary,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
