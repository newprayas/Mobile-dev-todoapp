import 'package:flutter/foundation.dart';

/// Simple debug logger used across the app.
/// In debug mode it prints a tagged message to the console only.
void debugLog(String tag, String message) {
  if (!kDebugMode) return;
  // ignore: avoid_print
  print('DEBUG [$tag]: $message');
}
