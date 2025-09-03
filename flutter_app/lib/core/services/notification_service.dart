import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import '../utils/debug_logger.dart';
import 'notifications/notification_constants.dart';
import 'notifications/notification_permission_manager.dart';
import 'notifications/persistent_notification_manager.dart';
import 'notifications/notification_sound_player.dart';

abstract class INotificationService {
  Function(String? payload)? onNotificationTap;
  Future<void> init();
  Future<void> ensurePermissions();
  Future<void> showNotification({required String title, required String body, String? payload, String? soundFileName});
  Future<void> showOrUpdatePersistent({
    required String title,
    required String body,
    required List<String> actionIds,
  });
  Future<void> cancelPersistentTimerNotification();
  Future<void> playSound(String soundFileName);
  Future<void> playSoundWithNotification({required String soundFileName, required String title, required String body});
}

class NotificationService implements INotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  late final NotificationPermissionManager _permissionManager = NotificationPermissionManager(_plugin);
  late final PersistentNotificationManager _persistentManager = PersistentNotificationManager(_plugin);
  late final NotificationSoundPlayer _soundPlayer = NotificationSoundPlayer();

  // Callback to handle notification tap, will be set in main.dart
  @override
  Function(String? payload)? onNotificationTap;

  @override
  Future<void> init() async {
    const AndroidInitializationSettings initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: initAndroid);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse resp) async {
        debugLog('NotificationService', 'Tap payload=${resp.payload} action=${resp.actionId}');
        final String? action = resp.actionId;
        if (action != null) {
          onNotificationTap?.call(action);
          return;
        }
        if (resp.payload == kPayloadOpenApp) {
          onNotificationTap?.call(resp.payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
    );
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(const AndroidNotificationChannel(
          'pomodoro_persistent_channel',
          'Persistent Pomodoro Timer',
          description: 'Ongoing notifications for your active Pomodoro timer.',
          importance: Importance.max,
          showBadge: false,
        ));
        await android.createNotificationChannel(const AndroidNotificationChannel(
          'pomodoro_channel',
          'Pomodoro Notifications',
          description: 'Notifications for Pomodoro timer events',
          importance: Importance.max,
        ));
      }
    }
    debugLog('NotificationService', 'Initialized & channels created');
  }

  /// Ensures the application has notification permissions (platform specific).
  /// On Android 13+ this requests the POST_NOTIFICATIONS runtime permission.
  /// On iOS/macOS it requests alert/badge/sound permissions.
  @override
  Future<void> ensurePermissions() => _permissionManager.ensurePermissions();

  // A method for triggering the background tap handler.
  // This needs to be a top-level function or a static method.
  @pragma('vm:entry-point')
  static void _notificationTapBackground(
    NotificationResponse notificationResponse,
  ) {
    debugLog('NotificationService', 'Background tap payload=${notificationResponse.payload} action=${notificationResponse.actionId}');
    final String? action = notificationResponse.actionId ?? notificationResponse.payload;
    if (action == null) return;
    // Persist for foreground polling (cannot access Provider scope here)
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.setString('last_notification_action', action);
      debugLog('NotificationService', 'Background action persisted action=$action');
    });
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload, // Add payload for generic notifications
    String? soundFileName, // Add sound parameter for notifications
  }) async {
  AndroidNotificationDetails androidPlatformChannelSpecifics;

    if (soundFileName != null) {
      // Use custom sound for notification
      final soundName = soundFileName.replaceAll(
        '.wav',
        '',
      ); // Remove extension
      androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'pomodoro_channel',
        'Pomodoro Notifications',
        channelDescription: 'Notifications for Pomodoro timer events',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false,
        sound: RawResourceAndroidNotificationSound(soundName),
        enableLights: true,
        enableVibration: true,
        playSound: true,
      );
    } else {
      // Use default notification without custom sound
      androidPlatformChannelSpecifics = const AndroidNotificationDetails(
        'pomodoro_channel',
        'Pomodoro Notifications',
        channelDescription: 'Notifications for Pomodoro timer events',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false,
      );
    }

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

  await _plugin.show(
      DateTime.now()
          .millisecondsSinceEpoch, // Unique ID for transient notifications
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  @override
  Future<void> showOrUpdatePersistent({
    required String title,
    required String body,
    required List<String> actionIds,
  }) => _persistentManager.showOrUpdate(title: title, body: body, actionIds: actionIds);

  /// Debug dump delegated to persistent manager (kept for backward compatibility if used internally later).
  Future<void> debugDumpActiveNotifications() => _persistentManager.debugDumpActiveNotifications();

  /// Cancels the persistent timer notification.
  @override
  Future<void> cancelPersistentTimerNotification() => _persistentManager.cancel();

  @override
  Future<void> playSound(String soundFileName) => _soundPlayer.playSound(soundFileName);

  /// Plays a sound AND shows a notification for critical events (like timer completion)
  /// This ensures sounds are heard even when the app is minimized
  @override
  Future<void> playSoundWithNotification({
    required String soundFileName,
    required String title,
    required String body,
  }) async {
    debugLog('NotificationService', 'playSoundWithNotification title="$title" body="$body" sound=$soundFileName');

    // First play the sound using the audio player
  await playSound(soundFileName);

    // Then show a notification with the same sound for background playback
    await showNotification(
      title: title,
      body: body,
  soundFileName: soundFileName,
      payload: 'sound_notification',
    );

  debugLog('NotificationService', 'Sound notification shown title="$title"');
  }
}
