/// Simple debug logger used across the app.
/// Always prints a tagged message to the console for debugging purposes.
void debugLog(String tag, String message) {
  // Always log - remove kDebugMode check for release build debugging
  // ignore: avoid_print
  print('DEBUG [$tag]: $message');
}
