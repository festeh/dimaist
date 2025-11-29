import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../providers/task_provider.dart';
import '../providers/project_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/font_provider.dart';
import '../providers/ai_model_provider.dart';
import '../providers/asr_language_provider.dart';
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
      // Sync both tasks and projects
      await ref.read(taskProvider.notifier).syncData();
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

  void _openModelManager() {
    showDialog(
      context: context,
      builder: (context) => const ModelListDialog(),
    );
  }

  TextStyle _getFontStyle(AppFont font) {
    switch (font) {
      case AppFont.inter:
        return GoogleFonts.inter();
      case AppFont.plusJakartaSans:
        return GoogleFonts.plusJakartaSans();
      case AppFont.nunito:
        return GoogleFonts.nunito();
      case AppFont.dmSans:
        return GoogleFonts.dmSans();
      case AppFont.outfit:
        return GoogleFonts.outfit();
      case AppFont.figtree:
        return GoogleFonts.figtree();
      case AppFont.spaceGrotesk:
        return GoogleFonts.spaceGrotesk();
    }
  }

  Widget _buildFontSelector() {
    final currentFont = ref.watch(fontProvider);
    final currentTheme = ref.watch(themeProvider);
    final colors = AppColors.forTheme(currentTheme);

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: AppFont.values.map((font) {
        final isSelected = font == currentFont;

        return Tooltip(
          message: font.description,
          child: InkWell(
            onTap: () => ref.read(fontProvider.notifier).setFont(font),
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
              child: Text(
                font.displayName,
                style: _getFontStyle(font).copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? colors.primary : null,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAsrLanguageSelector() {
    final currentLanguage = ref.watch(asrLanguageProvider);
    final currentTheme = ref.watch(themeProvider);
    final colors = AppColors.forTheme(currentTheme);

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: AsrLanguage.values.map((lang) {
        final isSelected = lang == currentLanguage;

        return InkWell(
          onTap: () => ref.read(asrLanguageProvider.notifier).setLanguage(lang),
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
            child: Text(
              lang.displayName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? colors.primary : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelState = ref.watch(aiModelProvider);
    final selectedModel = modelState.selectedModel;

    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                PhosphorIcon(PhosphorIcons.robot()),
                const SizedBox(width: 16),
                const Text(
                  'AI Model:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _openModelManager,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ModelDisplay(model: selectedModel),
                        ),
                        PhosphorIcon(PhosphorIcons.caretRight(), size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                PhosphorIcon(PhosphorIcons.palette()),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: PhosphorIcon(PhosphorIcons.textAa()),
                ),
                const SizedBox(width: 16),
                const Padding(
                  padding: EdgeInsets.only(top: Spacing.sm),
                  child: Text(
                    'Font:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFontSelector(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                PhosphorIcon(PhosphorIcons.globe()),
                const SizedBox(width: 16),
                const Text(
                  'ASR:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAsrLanguageSelector(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                PhosphorIcon(PhosphorIcons.arrowsClockwise()),
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
