/// Bridge to deliver notification action IDs from the notification plugin
/// callback (registered in `main.dart`) directly into Provider scope while
/// the app is alive. Falls back to SharedPreferences persistence when the
/// dispatcher hasn't been registered yet (early startup/background case).
///
/// Returns true if an action was synchronously dispatched to provider layer.
typedef NotificationActionCallback = bool Function(String actionId);

NotificationActionCallback? _notificationActionDispatcher;

void registerNotificationActionDispatcher(NotificationActionCallback cb) {
  _notificationActionDispatcher = cb;
}

void clearNotificationActionDispatcher() {
  _notificationActionDispatcher = null;
}

bool dispatchNotificationActionIfPossible(String actionId) {
  final NotificationActionCallback? cb = _notificationActionDispatcher;
  if (cb == null) return false;
  return cb(actionId);
}
