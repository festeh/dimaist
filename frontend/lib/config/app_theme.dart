import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  /// Creates a ThemeData for the specified theme mode
  static ThemeData create(AppThemeMode mode) {
    final colors = AppColors.forTheme(mode);
    final textTheme = _buildTextTheme(colors);

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,

      // Colors
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.background,
      cardColor: colors.surface,

      colorScheme: ColorScheme.dark(
        primary: colors.primary,
        onPrimary: colors.background,
        secondary: colors.secondary,
        onSecondary: colors.background,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        surfaceContainerHighest: colors.surfaceVariant,
        error: colors.error,
        onError: colors.textPrimary,
        outline: colors.border,
        outlineVariant: colors.borderSubtle,
      ),

      // Typography
      textTheme: textTheme,

      // Card theme
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: Sizes.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: colors.borderSubtle, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: Spacing.xs),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        hintStyle: TextStyle(color: colors.textMuted),
        labelStyle: TextStyle(color: colors.textSecondary),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          minimumSize: const Size(0, Sizes.touchTargetSmall),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          minimumSize: const Size(0, Sizes.touchTargetSmall),
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          minimumSize: const Size(0, Sizes.touchTargetSmall),
        ),
      ),

      // Icon button
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textSecondary,
          minimumSize: const Size(Sizes.touchTarget, Sizes.touchTarget),
        ),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colors.background),
        side: BorderSide(color: colors.border, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xs),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceVariant,
        labelStyle: TextStyle(color: colors.textPrimary, fontSize: 12),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: colors.border),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceVariant,
        contentTextStyle: TextStyle(color: colors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: colors.borderSubtle,
        thickness: 1,
        space: Spacing.lg,
      ),

      // List tile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.sm,
        ),
        minVerticalPadding: Spacing.sm,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),

      // Dropdown
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
            borderSide: BorderSide(color: colors.border),
          ),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(BaseColors colors) {
    return GoogleFonts.interTextTheme().copyWith(
      // Display
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        letterSpacing: -0.25,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
      ),
      // Headline
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      // Title
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        letterSpacing: 0.1,
      ),
      // Body
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        letterSpacing: 0.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        letterSpacing: 0.25,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
        letterSpacing: 0.4,
      ),
      // Label
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: colors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }
}
