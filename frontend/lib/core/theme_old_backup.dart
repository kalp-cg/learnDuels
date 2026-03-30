import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ═══════════════════════════════════════════════════════════════════════════
  // 🎨 CLASSIC MINIMAL THEME
  // Clean, off-white aesthetics with classic typography and minimal accents
  // ═══════════════════════════════════════════════════════════════════════════

  // ☁️ Base Colors
  // CodingGita Brand Colors
  static const Color background = Color(0xFFFBFBFD); // White
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color surfaceLight = Color(0xFFF7FAFC); // Light background

  // Brand & Accent
  static const Color primary = Color(0xFF5D21D0); // Brand Purple
  static const Color primaryDark = Color(
    0xFF2D354E,
  ); // Slate Blue (for dark text/secondary)
  static const Color secondary = Color(0xFFF7C83B); // CTA Yellow
  static const Color tertiary = Color(0xFF2D354E); // Slate Blue
  static const Color accent = Color(0xFFF7C83B); // CTA Yellow

  // Text Colors
  static const Color textPrimary = Color(0xFF060A18); // Navy Black
  static const Color textSecondary = Color(0xFF2D354E); // Slate Blue
  static const Color textMuted = Color(0xFF787780); // Neutral Gray

  // UI Elements
  static const Color border = Color(0xFFB6B7C1); // Light Gray
  static const Color divider = Color(0xFFB6B7C1); // Light Gray
  static const Color cardGlow = Colors.transparent;

  // Functional Colors
  static const Color error = Color(0xFFE53E3E); // Red
  static const Color success = Color(0xFF38A169); // Green
  static const Color warning = Color(0xFFF7C83B); // Yellow
  static const Color info = Color(0xFF5D21D0); // Brand Purple

  // Level/Rank Colors (unchanged)
  static const Color bronze = Color(0xFFCD7F32);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color gold = Color(0xFFFFD700);
  static const Color platinum = Color(0xFFE5E4E2);
  static const Color diamond = Color(0xFFB9F2FF);

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎭 THEME DATA
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData get academicTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primary,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: surface,
        error: error,
        outline: border,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),

      // Typography (unchanged)
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        bodySmall: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textMuted,
        ),
      ),

      // 📱 APP BAR
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textPrimary, size: 24),
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // 🔘 ELEVATED BUTTON
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ⭕ OUTLINED BUTTON
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: border, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),

      // 🃏 CARD
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),

      // 📝 INPUT DECORATION
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.outfit(color: textMuted),
        contentPadding: const EdgeInsets.all(16),
      ),

      // 🔽 BOTTOM NAVIGATION
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),

      // 🎯 ICON THEME
      iconTheme: const IconThemeData(color: textSecondary, size: 24),

      // 🔄 PROGRESS INDICATOR
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎨 HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  static LinearGradient get premiumGradient => const LinearGradient(
    colors: [primary, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration simpleDecoration({double borderRadius = 12}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: border),
    );
  }

  /// Glass morphism decoration -> Adapted for Minimal Theme to be a Clean Card
  static BoxDecoration glassDecoration({
    double borderRadius = 20,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: surface, // solid surface instead of glass
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? border, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
