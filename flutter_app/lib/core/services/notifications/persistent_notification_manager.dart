import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../utils/debug_logger.dart';
import 'notification_constants.dart';

/// Manages the persistent (ongoing) timer notification lifecycle.
class PersistentNotificationManager {
  final FlutterLocalNotificationsPlugin _plugin;
  PersistentNotificationManager(this._plugin);

  Future<void> showOrUpdate({
    required String title,
    required String body,
    required List<String> actionIds,
  }) async {
    final List<AndroidNotificationAction> actions = actionIds
        .map(
          (id) => AndroidNotificationAction(
            id,
            mapActionLabel(id),
            showsUserInterface: false,
            cancelNotification: false,
            contextual: false,
          ),
        )
        .toList();

    final BigTextStyleInformation bigText = BigTextStyleInformation(body);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'pomodoro_persistent_channel',
          'Persistent Pomodoro Timer',
          channelDescription:
              'Ongoing notifications for your active Pomodoro timer.',
          importance: Importance.max,
          priority: Priority.max,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          onlyAlertOnce: true,
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: bigText,
          actions: actions,
          category: AndroidNotificationCategory.service,
          visibility: NotificationVisibility.public,
          enableLights: false,
          enableVibration: false,
          playSound: false,
          ticker: title,
        );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      kPersistentTimerNotificationId,
      title,
      body,
      platformDetails,
      payload: kPayloadOpenApp,
    );
    logger.i(
      '[PersistentNotificationManager] Updated persistent title="$title" actions=$actionIds',
    );
    if (kDebugMode) {
      await debugDumpActiveNotifications();
    }
  }

  Future<void> cancel() async {
    await _plugin.cancel(kPersistentTimerNotificationId);
    logger.i(
      '[PersistentNotificationManager] Cancelled persistent notification',
    );
  }

  Future<void> debugDumpActiveNotifications() async {
    if (!Platform.isAndroid) return;
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl == null) return;
    try {
      final active = await androidImpl.getActiveNotifications();
      for (final n in active) {
        logger.d(
          '[PersistentNotificationManager] ACTIVE id=${n.id} tag=${n.tag} title=${n.title} text=${n.body}',
        );
      }
    } catch (e) {
      logger.e(
        '[PersistentNotificationManager] Error dumping active notifications: $e',
      );
    }
  }
}
