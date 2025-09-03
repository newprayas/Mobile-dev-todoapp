import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

/// Handles platform-specific notification permission requests.
class NotificationPermissionManager {
  final FlutterLocalNotificationsPlugin _plugin;
  final Logger logger = Logger();

  NotificationPermissionManager(this._plugin);

  Future<void> ensurePermissions() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImpl = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidImpl != null) {
          final bool? enabled = await androidImpl.areNotificationsEnabled();
          if (enabled == false) {
            final bool? granted = await androidImpl
                .requestNotificationsPermission();
            logger.i(
              '[NotificationPermissions] Requested Android permission granted=$granted',
            );
          } else {
            logger.i(
              '[NotificationPermissions] Android notifications already enabled',
            );
          }
        }
      } else if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? iosImpl = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (iosImpl != null) {
          final bool? granted = await iosImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          logger.i('[NotificationPermissions] iOS permission granted=$granted');
        }
      } else if (Platform.isMacOS) {
        final MacOSFlutterLocalNotificationsPlugin? macImpl = _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        if (macImpl != null) {
          final bool? granted = await macImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          logger.i(
            '[NotificationPermissions] macOS permission granted=$granted',
          );
        }
      }
    } catch (e) {
      logger.e('[NotificationPermissions] Error requesting permissions err=$e');
    }
  }
}
