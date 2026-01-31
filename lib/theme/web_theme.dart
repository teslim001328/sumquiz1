import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Professional color palette for web UI
/// Inspired by modern SaaS products like Notion, Linear, and Stripe
class WebColors {
  // Backgrounds
  static const background = Color(0xFFFDFDFF); // Off-white with tint
  static const backgroundAlt = Color(0xFFF3F4F6); // Light slate gray
  static const surface = Color(0xFFFFFFFF); // White cards

  // Primary colors - More vibrant premium indigo
  static const primary = Color(0xFF6366F1);
  static const primaryHover = Color(0xFF4F46E5);
  static const primaryLight = Color(0xFFEEF2FF);

  // Secondary - Tropical teal
  static const secondary = Color(0xFF0D9488);
  static const secondaryLight = Color(0xFFF0FDFA);

  // Text
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textTertiary = Color(0xFF94A3B8); // Slate 400

  // Borders
  static const border = Color(0xFFE5E7EB); // Slate 200 - slightly softer
  static const borderDark = Color(0xFFD1D5DB); // Slate 300

  // Accents
  static const Color accent = Color(0xFF8B5CF6); // Violet
  static const Color accentOrange = Color(0xFFF59E0B); // Amber
  static const Color accentPink = Color(0xFFEC4899); // Pink
  static const Color success = Color(0xFF10B981); // Emerald 500

  // Premium Gradients
  static const LinearGradient HeroGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient SurfaceGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF9FAFB)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.05),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get hoverShadow => [
        BoxShadow(
          color: const Color(0xFF6366F1).withOpacity(0.12),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
}

/// Professional theme data for web
class WebTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: WebColors.primary,
        primary: WebColors.primary,
        secondary: WebColors.secondary,
        surface: WebColors.surface,
        background: WebColors.background,
        onSurface: WebColors.textPrimary,
        onBackground: WebColors.textPrimary,
      ),
      scaffoldBackgroundColor: WebColors.background,

      // Premium Typography with Outfit
      textTheme: GoogleFonts.outfitTextTheme(const TextTheme(
        displayLarge: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w900,
          color: WebColors.textPrimary,
          height: 1.05,
          letterSpacing: -2.5,
        ),
        displayMedium: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w800,
          color: WebColors.textPrimary,
          height: 1.1,
          letterSpacing: -1.5,
        ),
        displaySmall: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: WebColors.textPrimary,
          letterSpacing: -1.0,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: WebColors.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: WebColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: WebColors.textPrimary,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: WebColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          color: WebColors.textSecondary,
          height: 1.65,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: WebColors.textSecondary,
          height: 1.55,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: WebColors.textSecondary,
          letterSpacing: 1.25,
        ),
      )),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WebColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WebColors.textPrimary,
          side: const BorderSide(color: WebColors.border, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WebColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // Visible Scrollbars for professional feel
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(true),
        thickness: WidgetStateProperty.all(6),
        thumbColor: WidgetStateProperty.all(WebColors.borderDark),
        radius: const Radius.circular(3),
        trackVisibility: WidgetStateProperty.all(true),
        trackColor: WidgetStateProperty.all(WebColors.backgroundAlt),
        crossAxisMargin: 2,
        mainAxisMargin: 4,
      ),

      // Premium Card Styling - FIXED CardThemeData
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: WebColors.border, width: 1),
        ),
        color: WebColors.surface,
        margin: EdgeInsets.zero,
      ),

      dividerTheme: const DividerThemeData(
        color: WebColors.border,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: WebColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: WebColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: WebColors.primary, width: 2),
        ),
        hintStyle: TextStyle(color: WebColors.textTertiary),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: WebColors.primary,
        primary: WebColors.primary,
        secondary: WebColors.secondary,
        surface: const Color(0xFF1E1E1E), // Dark surface
        background: const Color(0xFF121212), // Dark background
        onSurface: Colors.white,
        onBackground: Colors.white,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),

      // Premium Typography with Outfit
      textTheme: GoogleFonts.outfitTextTheme(const TextTheme(
        displayLarge: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.05,
          letterSpacing: -2.5,
        ),
        displayMedium: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.1,
          letterSpacing: -1.5,
        ),
        displaySmall: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -1.0,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          color: Colors.white70,
          height: 1.65,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: Colors.white70,
          height: 1.55,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white70,
          letterSpacing: 1.25,
        ),
      )),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WebColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white24, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WebColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // Visible Scrollbars for professional feel
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(true),
        thickness: WidgetStateProperty.all(6),
        thumbColor: WidgetStateProperty.all(Colors.white24),
        radius: const Radius.circular(3),
        trackVisibility: WidgetStateProperty.all(true),
        trackColor: WidgetStateProperty.all(Colors.white10),
        crossAxisMargin: 2,
        mainAxisMargin: 4,
      ),

      // Premium Card Styling for dark theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white12, width: 1),
        ),
        color: const Color(0xFF1E1E1E),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: const DividerThemeData(
        color: Colors.white12,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2D2D2D),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: WebColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(color: Colors.white60),
      ),
    );
  }
}
