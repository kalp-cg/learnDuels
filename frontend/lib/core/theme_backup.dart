import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // LearnDuels Design System
  // Colors
  static const Color primary = Color(0xFF20201F); // Dark Grey (from image)
  static const Color primaryHover = Color(0xFF000000);

  static const Color accent = Color(0xFFEE6E4D); // Salmon/Orange (from image)
  static const Color accentHover = Color(0xFFD05A3C); // Darker Salmon
  static const Color accentSoft = Color(0xFFFDF2EF); // Light Salmon

  static const Color secondary = Color(0xFF4A5D23); // Olive Ink
  static const Color secondarySoft = Color(0xFFEEF2E3);

  static const Color highlight = Color(0xFFC9A227); // Parchment Gold
  static const Color highlightSoft = Color(0xFFFBF6D9);

  static const Color bgMain = Color(0xFFFAF9F7); // Neutral Background
  static const Color bgCard = Color(0xFFFFFFFF); // White Card

  static const Color textPrimary = Color(0xFF20201F);
  static const Color textSecondary = Color(0xFF4A4A4A);
  static const Color textMuted = Color(0xFF6B6B6B);

  static const Color borderLight = Color(0xFFE3E1DC);
  static const Color divider = Color(0xFFD6D3CD);

  static const Color error = Color(0xFFD32F2F); // Standard error red

  static ThemeData get academicTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgMain,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: bgCard,
        error: error,
        tertiary: secondary,
        outline: borderLight,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.saira(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.saira(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displaySmall: GoogleFonts.saira(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.saira(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.saira(fontSize: 14, color: textSecondary),
        labelLarge: GoogleFonts.saira(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        labelMedium: GoogleFonts.dmMono(fontSize: 12, color: textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgCard,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.saira(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        shape: const Border(bottom: BorderSide(color: borderLight, width: 1)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.saira(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.saira(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: borderLight, width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12, // Height ~44px
        ),
        hintStyle: GoogleFonts.saira(color: textMuted),
        labelStyle: GoogleFonts.saira(color: textSecondary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgCard,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      iconTheme: const IconThemeData(color: textSecondary, size: 24),
    );
  }

  // Helper for Card Decoration (Manual usage)
  static BoxDecoration cardDecoration = BoxDecoration(
    color: bgCard,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: borderLight, width: 1),
  );

  // Helper for Active Sidebar/Nav Item
  static BoxDecoration activeNavDecoration = BoxDecoration(
    color: accentSoft,
    border: const Border(left: BorderSide(color: accent, width: 4)),
  );
}
