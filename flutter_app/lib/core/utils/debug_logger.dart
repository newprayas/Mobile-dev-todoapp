import 'package:logger/logger.dart';

/// Centralized logger instance for the application.
///
/// Provides structured and leveled logging with a clean, single-line output.
/// - `logger.d()`: Debug (for detailed tracing)
/// - `logger.i()`: Info (for general app flow)
/// - `logger.w()`: Warning
/// - `logger.e()`: Error (with error object and stack trace)
final logger = Logger(
  printer: SimplePrinter(
    colors: true, // Keep colored output
    printTime: false,
  ),
);
