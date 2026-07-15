/// Shared utility functions for BusAlert Cardiff.
///
/// Contains date formatting helpers, validation functions, and other
/// small reusable routines used across the application.
library;

import 'package:intl/intl.dart';

/// Validates an email address format.
///
/// Returns null if the email is valid, or an error message string if not.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email is required';
  }
  final emailRegex = RegExp(r'^[\w.+\-]+@[\w\-]+\.[\w\-]{2,}$');
  if (!emailRegex.hasMatch(value.trim())) {
    return 'Please enter a valid email address';
  }
  return null;
}

/// Validates a password meets minimum requirements.
///
/// Returns null if valid, or an error message string if not.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  if (value.length < 6) {
    return 'Password must be at least 6 characters';
  }
  return null;
}

/// Formats a [DateTime] to a user-friendly date string, e.g. "12 Jan 2026".
String formatDate(DateTime date) {
  return DateFormat('d MMM yyyy').format(date);
}

/// Formats a [DateTime] to a user-friendly time string, e.g. "14:30".
String formatTime(DateTime date) {
  return DateFormat('HH:mm').format(date);
}

/// Formats a duration in minutes to a human-readable string.
///
/// Example: 65 minutes -> "1h 5m"
String formatDurationMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours > 0) {
    return '${hours}h ${mins}m';
  }
  return '${mins}m';
}

/// Converts a speed in metres-per-second to kilometres-per-hour.
double msToKmh(double metersPerSecond) {
  return metersPerSecond * 3.6;
}

/// Parses a time string in "HH:mm" format to a [DateTime] on a given date.
///
/// Used when the backend returns a time-of-day string for schedule lookups.
DateTime parseTimeOfDay(String timeOfDay, {DateTime? onDate}) {
  final parts = timeOfDay.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  final date = onDate ?? DateTime.now();
  return DateTime(date.year, date.month, date.day, hour, minute);
}

/// Clamps a value between [min] and [max].
double clampDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
