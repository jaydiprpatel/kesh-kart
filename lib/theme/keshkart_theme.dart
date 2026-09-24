import 'package:flutter/material.dart';

class KeshColors {
  static const Color navyPrimary = Color(0xFF091426);
  static const Color navySurface = Color(0xFF111C2E);
  static const Color warmIvory = Color(0xFFFAF7F2);
  static const Color cardSurface = Colors.white;
  static const Color signatureCoral = Color(0xFFE2613B);
  static const Color coralHover = Color(0xFFC84E2A);
  static const Color proGold = Color(0xFFD6A84B);
  static const Color emeraldSuccess = Color(0xFF10B981);
  static const Color textPrimary = Color(0xFF091426);
  static const Color textSecondary = Color(0xFF45474C);
  static const Color textMuted = Color(0xFF8C8E94);
  static const Color borderIvory = Color(0xFFE8E2D5);
  static const Color chipBackground = Color(0xFFF2EBDC);
}

class KeshTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: KeshColors.warmIvory,
      primaryColor: KeshColors.signatureCoral,
      colorScheme: ColorScheme.light(
        primary: KeshColors.signatureCoral,
        onPrimary: Colors.white,
        surface: KeshColors.warmIvory,
        onSurface: KeshColors.textPrimary,
        secondary: KeshColors.navyPrimary,
        onSecondary: Colors.white,
        secondaryContainer: KeshColors.chipBackground,
        onSecondaryContainer: KeshColors.navyPrimary,
        tertiary: KeshColors.proGold,
      ),
      fontFamily: 'Popins',
      appBarTheme: const AppBarTheme(
        backgroundColor: KeshColors.warmIvory,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: KeshColors.navyPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Popins',
          color: KeshColors.navyPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: KeshColors.cardSurface,
        elevation: 2,
        shadowColor: KeshColors.navyPrimary.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: KeshColors.borderIvory, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: KeshColors.borderIvory),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: KeshColors.borderIvory),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: KeshColors.signatureCoral,
            width: 2,
          ),
        ),
        hintStyle: const TextStyle(color: KeshColors.textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: KeshColors.signatureCoral,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Popins',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
