import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';

// Notification service provider - will be overridden in main.dart
final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('notificationServiceProvider must be overridden');
});
