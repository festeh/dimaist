import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData darkTheme(BuildContext context) {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF6200EE),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6200EE),
        brightness: Brightness.dark,
        secondary: const Color(0xFF03DAC6),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme)
          .copyWith(
            headlineSmall: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            bodyLarge: const TextStyle(fontSize: 16, color: Colors.white),
            bodyMedium: const TextStyle(fontSize: 14, color: Colors.white),
          ),
    );
  }
}