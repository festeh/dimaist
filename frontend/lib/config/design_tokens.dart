import 'package:flutter/material.dart';

/// Design tokens for consistent spacing, sizing, and styling across the app.
/// Based on a 4px base unit for mathematical consistency.
class Spacing {
  Spacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

class Radii {
  Radii._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 9999;
}

class Sizes {
  Sizes._();

  // Touch targets (minimum 44px for accessibility)
  static const double touchTarget = 48;
  static const double touchTargetSmall = 44;

  // Icons
  static const double iconXs = 16;
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 32;

  // Avatars
  static const double avatarSm = 12;
  static const double avatarMd = 16;

  // Layout
  static const double sidebarWidth = 248;
  static const double dialogWidth = 300;
  static const double maxContentWidth = 800;

  // Cards
  static const double cardElevation = 0;
  static const double cardElevationHover = 2;
}

class Durations {
  Durations._();

  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration slower = Duration(milliseconds: 500);
}

/// App theme identifiers
enum AppThemeMode {
  midnight('Midnight', 'Deep navy with cyan accents'),
  earth('Earth', 'Warm greys with terracotta accents'),
  purple('Purple', 'Classic purple with teal accents'),
  mono('Mono', 'Clean slate greys with blue accent');

  final String displayName;
  final String description;

  const AppThemeMode(this.displayName, this.description);
}

/// Color palettes for each theme
class AppColors {
  AppColors._();

  // Midnight theme - modern, tech-forward
  static const midnight = _MidnightColors();

  // Earth theme - warm, organic
  static const earth = _EarthColors();

  // Purple theme - original Material-esque
  static const purple = _PurpleColors();

  // Mono theme - minimal, focused
  static const mono = _MonoColors();

  static BaseColors forTheme(AppThemeMode theme) {
    switch (theme) {
      case AppThemeMode.midnight:
        return midnight;
      case AppThemeMode.earth:
        return earth;
      case AppThemeMode.purple:
        return purple;
      case AppThemeMode.mono:
        return mono;
    }
  }
}

/// Base class for theme colors
abstract class BaseColors {
  // Background colors
  Color get background;
  Color get surface;
  Color get surfaceVariant;

  // Text colors
  Color get textPrimary;
  Color get textSecondary;
  Color get textMuted;

  // Accent colors
  Color get primary;
  Color get primaryVariant;
  Color get secondary;

  // Semantic colors
  Color get error;
  Color get success;
  Color get warning;

  // Border colors
  Color get border;
  Color get borderSubtle;
}

class _MidnightColors implements BaseColors {
  const _MidnightColors();

  @override
  Color get background => const Color(0xFF0D1117);
  @override
  Color get surface => const Color(0xFF161B22);
  @override
  Color get surfaceVariant => const Color(0xFF21262D);

  @override
  Color get textPrimary => const Color(0xFFF0F6FC);
  @override
  Color get textSecondary => const Color(0xFF8B949E);
  @override
  Color get textMuted => const Color(0xFF6E7681);

  @override
  Color get primary => const Color(0xFF58A6FF);
  @override
  Color get primaryVariant => const Color(0xFF388BFD);
  @override
  Color get secondary => const Color(0xFF3FB950);

  @override
  Color get error => const Color(0xFFF85149);
  @override
  Color get success => const Color(0xFF3FB950);
  @override
  Color get warning => const Color(0xFFD29922);

  @override
  Color get border => const Color(0xFF30363D);
  @override
  Color get borderSubtle => const Color(0xFF21262D);
}

class _EarthColors implements BaseColors {
  const _EarthColors();

  @override
  Color get background => const Color(0xFF1C1917);
  @override
  Color get surface => const Color(0xFF292524);
  @override
  Color get surfaceVariant => const Color(0xFF3D3835);

  @override
  Color get textPrimary => const Color(0xFFFAFAF9);
  @override
  Color get textSecondary => const Color(0xFFA8A29E);
  @override
  Color get textMuted => const Color(0xFF78716C);

  @override
  Color get primary => const Color(0xFFEA580C);
  @override
  Color get primaryVariant => const Color(0xFFC2410C);
  @override
  Color get secondary => const Color(0xFF84CC16);

  @override
  Color get error => const Color(0xFFDC2626);
  @override
  Color get success => const Color(0xFF16A34A);
  @override
  Color get warning => const Color(0xFFCA8A04);

  @override
  Color get border => const Color(0xFF44403C);
  @override
  Color get borderSubtle => const Color(0xFF373533);
}

class _PurpleColors implements BaseColors {
  const _PurpleColors();

  @override
  Color get background => const Color(0xFF121212);
  @override
  Color get surface => const Color(0xFF1E1E1E);
  @override
  Color get surfaceVariant => const Color(0xFF2D2D2D);

  @override
  Color get textPrimary => const Color(0xFFFFFFFF);
  @override
  Color get textSecondary => const Color(0xFFB3B3B3);
  @override
  Color get textMuted => const Color(0xFF757575);

  @override
  Color get primary => const Color(0xFFBB86FC);
  @override
  Color get primaryVariant => const Color(0xFF9A67EA);
  @override
  Color get secondary => const Color(0xFF03DAC6);

  @override
  Color get error => const Color(0xFFCF6679);
  @override
  Color get success => const Color(0xFF4CAF50);
  @override
  Color get warning => const Color(0xFFFFB74D);

  @override
  Color get border => const Color(0xFF3D3D3D);
  @override
  Color get borderSubtle => const Color(0xFF2D2D2D);
}

class _MonoColors implements BaseColors {
  const _MonoColors();

  @override
  Color get background => const Color(0xFF0F172A);
  @override
  Color get surface => const Color(0xFF1E293B);
  @override
  Color get surfaceVariant => const Color(0xFF334155);

  @override
  Color get textPrimary => const Color(0xFFF8FAFC);
  @override
  Color get textSecondary => const Color(0xFF94A3B8);
  @override
  Color get textMuted => const Color(0xFF64748B);

  @override
  Color get primary => const Color(0xFF3B82F6);
  @override
  Color get primaryVariant => const Color(0xFF2563EB);
  @override
  Color get secondary => const Color(0xFF06B6D4);

  @override
  Color get error => const Color(0xFFEF4444);
  @override
  Color get success => const Color(0xFF22C55E);
  @override
  Color get warning => const Color(0xFFF59E0B);

  @override
  Color get border => const Color(0xFF475569);
  @override
  Color get borderSubtle => const Color(0xFF334155);
}
