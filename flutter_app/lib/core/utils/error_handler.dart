import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

/// Centralized error handling utility for the app
class ErrorHandler {
  /// Converts exceptions into user-friendly error messages
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timeout. Please check your internet connection.';
        case DioExceptionType.connectionError:
          return 'Cannot connect to server. Please check your internet connection.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 401) {
            return 'Authentication failed. Please sign in again.';
          } else if (statusCode == 403) {
            return 'Access denied. Please contact support.';
          } else if (statusCode == 404) {
            return 'Resource not found. Please try again.';
          } else if (statusCode == 500) {
            return 'Server error. Please try again later.';
          } else {
            return 'Request failed (Error $statusCode). Please try again.';
          }
        default:
          return 'Network error. Please check your connection.';
      }
    } else if (error.toString().toLowerCase().contains('connection')) {
      return 'Connection failed. Please check your internet connection.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Shows a user-friendly error message using SnackBar
  static void showError(BuildContext context, dynamic error) {
    if (!context.mounted) return;

    final message = getErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Shows a success message using SnackBar
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows an info message using SnackBar
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
