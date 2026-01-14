import 'package:flutter/material.dart';

/// Professional color palette for web UI
/// Inspired by modern SaaS products like Notion, Linear, and Stripe
class WebColors {
  // Backgrounds
  static const background = Color(0xFFFFFFFF); // Pure white
  static const backgroundAlt = Color(0xFFF9FAFB); // Light gray
  static const surface = Color(0xFFFFFFFF); // White cards

  // Primary colors
  static const primary = Color(0xFF4F46E5); // Professional indigo
  static const primaryHover = Color(0xFF4338CA); // Darker on hover
  static const primaryLight = Color(0xFFEEF2FF); // Light tint

  // Secondary
  static const secondary = Color(0xFF10B981); // Success green
  static const secondaryLight = Color(0xFFD1FAE5); // Light tint

  // Text
  static const Color textPrimary = Color(0xFF111827); // Almost black
  static const Color textSecondary = Color(0xFF6B7280); // Medium gray
  static const Color textTertiary = Color(0xFF9CA3AF); // Light gray

  // Borders
  static const border = Color(0xFFE5E7EB); // Light border
  static const borderDark = Color(0xFFD1D5DB); // Darker border

  // Accents
  static const Color accent = Color(0xFF8B5CF6); // Purple
  static const Color accentOrange = Color(0xFFF59E0B); // Orange
  static const Color accentPink = Color(0xFFEC4899); // Pink

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 40,
          offset: const Offset(0, 20),
        ),
      ];

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
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
      colorScheme: ColorScheme.light(
        primary: WebColors.primary,
        secondary: WebColors.secondary,
        surface: WebColors.surface,
        background: WebColors.background,
      ),
      scaffoldBackgroundColor: WebColors.background,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w700,
          color: WebColors.textPrimary,
          height: 1.1,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: WebColors.textPrimary,
          height: 1.1,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          color: WebColors.textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: WebColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: WebColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: WebColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: WebColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 20,
          color: WebColors.textSecondary,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: WebColors.textSecondary,
          height: 1.6,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WebColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WebColors.textPrimary,
          side: const BorderSide(color: WebColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WebColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
