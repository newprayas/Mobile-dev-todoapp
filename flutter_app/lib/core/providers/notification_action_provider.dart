import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the latest notification action id triggered by the user.
/// TimerNotifier listens to this and performs the corresponding action,
/// then we immediately clear it (set to null) to avoid repeated handling.
final notificationActionProvider = StateProvider<String?>((ref) => null);
