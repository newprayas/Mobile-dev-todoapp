import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../utils/debug_logger.dart';
import 'dart:io' show Platform; // For platform checks

// A unique ID for the persistent timer notification.
const int _kPersistentTimerNotificationId = 1;
// Action ID for the pause/resume button within the notification.
const String _kNotificationActionPause = 'pause_timer';
const String _kNotificationActionResume = 'resume_timer';
const String _kNotificationActionStop = 'stop_timer';
const String _kNotificationActionMarkComplete = 'mark_complete';
const String _kNotificationActionContinueWorking = 'continue_working';
// Payload key to determine if the notification tap is to open the app.
const String _kNotificationPayloadOpenApp = 'open_app';

abstract class INotificationService {
  Function(String? payload)? onNotificationTap;
  Future<void> init();
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
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Callback to handle notification tap, will be set in main.dart
  @override
  Function(String? payload)? onNotificationTap;

  @override
  Future<void> init() async {
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        debugLog('NotificationService', 'Notification tapped payload=${notificationResponse.payload} action=${notificationResponse.actionId}');
        final action = notificationResponse.actionId;
        if (action == _kNotificationActionPause || action == _kNotificationActionResume) {
          onNotificationTap?.call(action); // pass through
        } else if (action == _kNotificationActionStop) {
          onNotificationTap?.call(action);
        } else if (action == _kNotificationActionMarkComplete) {
          onNotificationTap?.call(action);
        } else if (action == _kNotificationActionContinueWorking) {
          onNotificationTap?.call(action);
        } else if (notificationResponse.payload == _kNotificationPayloadOpenApp) {
          onNotificationTap?.call(notificationResponse.payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          _notificationTapBackground, // For background actions
    );

    if (Platform.isAndroid) {
      // Explicitly create channels to avoid reliance on implicit creation.
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'pomodoro_persistent_channel',
            'Persistent Pomodoro Timer',
            description: 'Ongoing notifications for your active Pomodoro timer.',
            importance: Importance.max,
            showBadge: false,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'pomodoro_channel',
            'Pomodoro Notifications',
            description: 'Notifications for Pomodoro timer events',
            importance: Importance.max,
          ),
        );
      }
    }

    if (kDebugMode) debugLog('NotificationService', 'Initialized & channels created');
  }

  // A method for triggering the background tap handler.
  // This needs to be a top-level function or a static method.
  @pragma('vm:entry-point')
  static void _notificationTapBackground(
    NotificationResponse notificationResponse,
  ) {
  debugLog('NotificationService', 'Background tap payload=${notificationResponse.payload} action=${notificationResponse.actionId}');

    // This is where background actions would be handled.
    // For the pause/resume action, we would need to trigger the Workmanager
    // task again to toggle the timer. This requires careful state management.
    // We'll address this in main.dart callbackDispatcher.
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

    await _notificationsPlugin.show(
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
  }) async {
    // Map simple string action IDs to AndroidNotificationAction
    final List<AndroidNotificationAction> actions = actionIds.map((String id) {
      return AndroidNotificationAction(
        id,
        _mapActionLabel(id),
        showsUserInterface: false,
        cancelNotification: false,
        contextual: false,
      );
    }).toList();

    // Use BigTextStyle to keep layout simple and ensure actions are visible.
    final BigTextStyleInformation bigText = BigTextStyleInformation(body);

    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'pomodoro_persistent_channel',
      'Persistent Pomodoro Timer',
      channelDescription: 'Ongoing notifications for your active Pomodoro timer.',
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

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      _kPersistentTimerNotificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: _kNotificationPayloadOpenApp,
    );

    debugLog('NotificationService', 'Persistent update title="$title" body="$body" actions=$actionIds');
    if (kDebugMode) {
      await debugDumpActiveNotifications();
    }
  }

  String _mapActionLabel(String id) {
    switch (id) {
      case _kNotificationActionPause:
        return 'Pause';
      case _kNotificationActionResume:
        return 'Resume';
      case _kNotificationActionStop:
        return 'Stop';
      case _kNotificationActionMarkComplete:
        return 'Complete';
      case _kNotificationActionContinueWorking:
        return 'Continue';
      default:
        return id;
    }
  }

  /// Debug helper: logs currently active notifications (Android only)
  Future<void> debugDumpActiveNotifications() async {
    if (!Platform.isAndroid) return;
    final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;
    try {
      final active = await androidImpl.getActiveNotifications();
      for (final n in active) {
        debugLog('NotificationService', 'ACTIVE notif id=${n.id} tag=${n.tag} title=${n.title} text=${n.body}');
      }
    } catch (e) {
      debugLog('NotificationService', 'Error dumping active notifications: $e');
    }
  }

  /// Cancels the persistent timer notification.
  @override
  Future<void> cancelPersistentTimerNotification() async {
    await _notificationsPlugin.cancel(_kPersistentTimerNotificationId);
    debugLog('NotificationService', 'Persistent notification cancelled');
  }

  @override
  Future<void> playSound(String soundFileName) async {
    try {
      debugLog('NotificationService', 'playSound sound=$soundFileName');

      // Stop any currently playing sound first
      await _audioPlayer.stop();

      String assetPath = soundFileName;
      if (assetPath.startsWith('assets/sounds/')) {
        assetPath = assetPath.substring(14);
      } else if (assetPath.startsWith('assets/')) {
        assetPath = assetPath.substring(7);
      } else if (assetPath.startsWith('sounds/')) {
        assetPath = assetPath.substring(7);
      }

  debugLog('NotificationService', 'Processed assetPath=$assetPath');

      // Add a small delay to ensure the previous sound is fully stopped
      await Future.delayed(const Duration(milliseconds: 50));

      await _audioPlayer.play(AssetSource('sounds/$assetPath'));
  debugLog('NotificationService', 'Sound played sound=$soundFileName');

      // Add extra debugging for specific sounds
      if (soundFileName.contains('break_timer_start')) {
        debugLog('NotificationService', 'Break timer sound played');
      } else if (soundFileName.contains('progress_bar_full')) {
        debugLog('NotificationService', 'Progress bar full sound played');
      }
    } catch (e, stackTrace) {
      debugLog('NotificationService', 'Error playing sound=$soundFileName err=$e');
      debugLog('NotificationService', 'Stack trace: $stackTrace');

      // Try alternative approach for problematic sounds
      if (soundFileName.contains('break_timer_start') ||
          soundFileName.contains('progress_bar_full')) {
        debugLog('NotificationService', 'Attempt alternative playback sound=$soundFileName');
        try {
          await _audioPlayer.setSource(AssetSource('sounds/$soundFileName'));
          await _audioPlayer.resume();
          debugLog('NotificationService', 'Alternative playback success sound=$soundFileName');
        } catch (alternativeError) {
          debugLog('NotificationService', 'Alternative playback failed err=$alternativeError');
        }
      }
    }
  }

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
