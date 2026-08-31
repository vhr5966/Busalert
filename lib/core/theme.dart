/// Material 3 theme configuration for BusAlert Cardiff.
///
/// Uses a Cardiff-blue (#2E5496) primary color throughout the app.
/// All screens follow Material Design 3 guidelines for consistency.
library;

import 'package:flutter/material.dart';

/// The Cardiff blue used as the primary brand colour.
const Color kCardiffBlue = Color(0xFF2E5496);

/// A lighter tint of Cardiff blue for surfaces and cards.
const Color kCardiffBlueLight = Color(0xFFE8EFF8);

/// A darker shade for text on light backgrounds.
const Color kTextPrimary = Color(0xFF1A1A2E);

/// Secondary accent colour — a warm amber used for delay warnings.
const Color kAmberAccent = Color(0xFFFFB300);

/// Error / major-delay red.
const Color kDelayRed = Color(0xFFD32F2F);

/// On-time green.
const Color kOnTimeGreen = Color(0xFF388E3C);

/// Creates the Material 3 light theme for the application.
///
/// All colour tokens are derived from the Cardiff blue seed colour.
ThemeData buildAppTheme() {
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: kCardiffBlue,
    brightness: Brightness.light,
    primary: kCardiffBlue,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: kTextPrimary,
    secondary: kAmberAccent,
    error: kDelayRed,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,

    // ── AppBar ──────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),

    // ── Cards ───────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    // ── Elevated Buttons ────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size(64, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── Input Fields ────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCardiffBlueLight.withAlpha(80),
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
        borderSide: const BorderSide(color: kCardiffBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // ── Typography ──────────────────────────────────────────────────────
    textTheme: TextTheme(
      headlineLarge: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: kTextPrimary,
      ),
      headlineMedium: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: kTextPrimary,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: kTextPrimary,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        color: kTextPrimary,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        color: kTextPrimary,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: kTextPrimary,
      ),
    ),
  );
}

/// Helper to get a colour representing the delay severity.
///
/// Used throughout the app to colour-code delay indicators.
/// * [delayMinutes] can be negative (early), zero (on time), or positive (late).
Color delayColor(double delayMinutes) {
  if (delayMinutes <= 2) return kOnTimeGreen;
  if (delayMinutes <= 10) return kAmberAccent;
  return kDelayRed;
}

/// Human-readable label for a delay value.
String delayLabel(double delayMinutes) {
  if (delayMinutes <= 2) return 'On time';
  if (delayMinutes <= 10) return 'Minor delay';
  return 'Major delay';
}
