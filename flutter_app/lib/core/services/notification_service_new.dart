import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart'; // For @required
import '../theme/app_colors.dart';

// A unique ID for the persistent timer notification.
const int _kPersistentTimerNotificationId = 1;
// Action ID for the pause/resume button within the notification.
const String _kNotificationActionPauseResume = 'pause_resume';
// Payload key to determine if the notification tap is to open the app.
const String _kNotificationPayloadOpenApp = 'open_app';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Callback to handle notification tap, will be set in main.dart
  Function(String? payload)? onNotificationTap;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        debugPrint(
          'DEBUG: Notification tapped - Payload: ${notificationResponse.payload}, Action: ${notificationResponse.actionId}',
        );
        // Handle notification taps
        if (notificationResponse.actionId == _kNotificationActionPauseResume) {
          // Action button was tapped. We need to send this to the main app isolate
          // or handle it directly in the Workmanager callback for background.
          // For now, we'll assume the main app will detect the state change.
          // In a real app, you might use a MethodChannel here if foreground, or
          // update shared preferences/trigger another Workmanager task if background.
          debugPrint(
            'DEBUG: Notification Pause/Resume action tapped. Payload: ${notificationResponse.payload}',
          );
          onNotificationTap?.call(notificationResponse.payload);
        } else if (notificationResponse.payload ==
            _kNotificationPayloadOpenApp) {
          // Tapped the body of the notification to open the app
          debugPrint('DEBUG: Notification body tapped to open app.');
          // The app will naturally resume if it's in the background
          // No special navigation needed here unless you want to deep-link.
          onNotificationTap?.call(notificationResponse.payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          _notificationTapBackground, // For background actions
    );

    if (kDebugMode) {
      debugPrint('DEBUG: NotificationService initialized');
    }
  }

  // A method for triggering the background tap handler.
  // This needs to be a top-level function or a static method.
  @pragma('vm:entry-point')
  static void _notificationTapBackground(
    NotificationResponse notificationResponse,
  ) {
    debugPrint(
      'DEBUG: Background Notification tapped - Payload: ${notificationResponse.payload}, Action: ${notificationResponse.actionId}',
    );

    // This is where background actions would be handled.
    // For the pause/resume action, we would need to trigger the Workmanager
    // task again to toggle the timer. This requires careful state management.
    // We'll address this in main.dart callbackDispatcher.
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload, // Add payload for generic notifications
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'pomodoro_channel',
          'Pomodoro Notifications',
          channelDescription: 'Notifications for Pomodoro timer events',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
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

  /// Shows a persistent notification for the active timer.
  Future<void> showPersistentTimerNotification({
    required String taskName,
    required String timeRemaining,
    required String currentMode,
    required bool isRunning,
    required bool isFocusMode,
  }) async {
    final String title = isFocusMode ? 'FOCUS TIME' : 'BREAK TIME';
    final String body = 'Task: $taskName ($timeRemaining)';
    final String subText = isFocusMode
        ? 'Focus session active'
        : 'Break session active';

    // The action for the notification button
    final AndroidNotificationAction action = AndroidNotificationAction(
      _kNotificationActionPauseResume,
      isRunning ? 'Pause' : 'Resume',
      showsUserInterface: false, // Don't open the app just for this button
    );

    // Deprecated placeholder. Use notification_service.dart instead.
      await _audioPlayer.play(AssetSource('sounds/$assetPath'));
      debugPrint('DEBUG: Sound played successfully: $soundFileName');
    } catch (e, stackTrace) {
      debugPrint('DEBUG: Error playing sound $soundFileName: $e');
      debugPrint('DEBUG: Stack trace: $stackTrace');
    }
  }

  Future<void> testBreakSound() async {
    debugPrint('DEBUG: Testing BREAK TIMER sound specifically...');
    debugPrint('DEBUG: Sound file path: break_timer_start.wav');
    await playSound('break_timer_start.wav');
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('DEBUG: Break timer sound test completed');
  }

  Future<void> testBreakSoundImmediate() async {
    debugPrint('DEBUG: IMMEDIATE break timer sound test...');
    try {
      await playSound('break_timer_start.wav');
      debugPrint('DEBUG: IMMEDIATE break timer sound succeeded');
    } catch (e) {
      debugPrint('DEBUG: IMMEDIATE break timer sound failed: $e');
    }
  }

  Future<void> testAllSounds() async {
    debugPrint('DEBUG: Testing all sound files...');

    final sounds = [
      'break_timer_start.wav',
      'focus_timer_start.wav',
      'progress_bar_full.wav',
    ];

    for (final sound in sounds) {
      debugPrint('DEBUG: Testing sound: $sound');
      await playSound(sound);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    debugPrint('DEBUG: All sound tests completed');
  }
}
