/// Centralized application logger for BusAlert.
///
/// Complies with engineering standards:
/// - Logger lives under lib/core/logger
/// - Uses debug, info, warn, and error levels
/// - Never logs sensitive credentials, tokens, or PII
library;

import 'dart:developer' as developer;

class AppLogger {
  AppLogger._();

  static const String _tag = 'BusAlert';

  /// Logs detailed development information.
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: '$_tag:DEBUG',
      level: 500,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs normal application flow and events.
  static void info(String message) {
    developer.log(
      message,
      name: '$_tag:INFO',
      level: 800,
    );
  }

  /// Logs recoverable issues or warnings.
  static void warn(String message, [Object? error]) {
    developer.log(
      message,
      name: '$_tag:WARN',
      level: 900,
      error: error,
    );
  }

  /// Logs critical errors and exceptions.
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: '$_tag:ERROR',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
