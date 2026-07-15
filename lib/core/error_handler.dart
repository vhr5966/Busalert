/// Error handling utilities for BusAlert Cardiff.
///
/// Provides a consistent way to handle and display errors across the app,
/// including network errors, server errors, and validation errors.
library;

import 'package:flutter/material.dart';

/// Represents an application-level error with a user-friendly message.
class AppError {
  /// A message suitable for showing to the user.
  final String userMessage;

  /// An optional technical detail for debugging.
  final String? technicalDetail;

  const AppError({
    required this.userMessage,
    this.technicalDetail,
  });

  @override
  String toString() =>
      'AppError: $userMessage${technicalDetail != null ? ' ($technicalDetail)' : ''}';
}

/// Parses various exception types into a consistent [AppError].
///
/// This function translates DioExceptions, network errors, and raw server
/// responses into user-friendly messages so the UI never shows raw
/// exception text.
AppError parseError(dynamic error) {
  // Handle DioError (HTTP client errors)
  if (error.toString().contains('DioException')) {
    final msg = error.toString();
    if (msg.contains('Connection refused') || msg.contains('SocketException')) {
      return const AppError(
        userMessage: 'Could not connect to the server. Please check your '
            'internet connection and try again.',
        technicalDetail: 'Connection refused',
      );
    }
    if (msg.contains('statusCode: 401')) {
      return const AppError(
        userMessage: 'Your session has expired. Please log in again.',
        technicalDetail: '401 Unauthorized',
      );
    }
    if (msg.contains('statusCode: 403')) {
      return const AppError(
        userMessage: 'You do not have permission to perform this action.',
        technicalDetail: '403 Forbidden',
      );
    }
    if (msg.contains('statusCode: 404')) {
      return const AppError(
        userMessage: 'The requested resource was not found.',
        technicalDetail: '404 Not Found',
      );
    }
    if (msg.contains('statusCode: 500')) {
      return const AppError(
        userMessage: 'The server encountered an error. Please try again later.',
        technicalDetail: '500 Internal Server Error',
      );
    }
    return const AppError(
      userMessage: 'Something went wrong. Please try again.',
    );
  }

  // Handle generic exceptions
  if (error is AppError) return error;

  return AppError(
    userMessage: error.toString().contains('Timeout')
        ? 'The request timed out. Please check your connection.'
        : 'An unexpected error occurred. Please try again.',
    technicalDetail: error.toString(),
  );
}

/// Shows a [SnackBar] with an error message.
///
/// Call this from any screen context to display errors consistently.
void showErrorSnackBar(BuildContext context, AppError error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(error.userMessage),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
}
