import 'dart:typed_data'; // For Int32List
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import '../theme/app_colors.dart';

// A unique ID for the persistent timer notification.
const int _kPersistentTimerNotificationId = 1;
// Action ID for the pause/resume button within the notification.
const String _kNotificationActionPauseResume = 'pause_resume';
// Action ID for the stop button within the notification.
const String _kNotificationActionStop = 'stop_timer';
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
          // Pause/Resume action button was tapped
          debugPrint(
            'DEBUG: Notification Pause/Resume action tapped. Payload: ${notificationResponse.payload}',
          );
          onNotificationTap?.call('pause_resume_timer');
        } else if (notificationResponse.actionId == 'stop_timer') {
          // Stop action button was tapped
          debugPrint(
            'DEBUG: Notification Stop action tapped. Payload: ${notificationResponse.payload}',
          );
          onNotificationTap?.call('stop_timer');
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

  /// Shows a persistent notification for the active timer.
  Future<void> showPersistentTimerNotification({
    required String taskName,
    required String timeRemaining,
    required String currentMode,
    required bool isRunning,
    required bool isFocusMode,
  }) async {
    final String title = isFocusMode ? '🎯 FOCUS TIME' : '☕ BREAK TIME';
    final String body = '$taskName • $timeRemaining';
    final String subText = isRunning
        ? (isFocusMode ? '🔥 Focusing now...' : '✨ Take a break')
        : (isFocusMode ? '⏸️ Focus paused' : '⏸️ Break paused');

    // Create media-style action buttons with icons
    final List<AndroidNotificationAction> actions = [
      AndroidNotificationAction(
        _kNotificationActionPauseResume,
        isRunning ? '⏸️ Pause' : '▶️ Resume',
        showsUserInterface: false,
        cancelNotification: false,
        // Make this action more prominent
        contextual: false,
      ),
      AndroidNotificationAction(
        'stop_timer',
        '⏹️ Stop',
        showsUserInterface: false,
        cancelNotification: false,
        contextual: false,
      ),
    ];

    // Use MediaStyleInformation for a bigger, Spotify-like notification
    final MediaStyleInformation mediaStyleInformation = MediaStyleInformation(
      htmlFormatContent: true,
      htmlFormatTitle: true,
    );

    final AndroidNotificationDetails
    androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'pomodoro_persistent_channel', // New channel for persistent notifications
      'Persistent Pomodoro Timer',
      channelDescription:
          'Ongoing notifications for your active Pomodoro timer.',
      importance:
          Importance.max, // Maximum importance for better background visibility
      priority: Priority.max, // Maximum priority for media-style notifications
      ongoing: true, // Make it persistent
      autoCancel: false, // Don't auto-cancel when tapped
      showWhen: false,
      onlyAlertOnce: true, // Prevent repeated sound/vibration
      color: isFocusMode ? AppColors.focusRed : AppColors.breakGreen,
      // Use a larger, more prominent icon
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      // Use MediaStyleInformation for Spotify-like appearance
      styleInformation: mediaStyleInformation,
      actions: actions,
      // Enhanced flags for background operation
      additionalFlags: Int32List.fromList([
        4, // FLAG_NO_CLEAR
        16, // FLAG_ONGOING_EVENT
        64, // FLAG_FOREGROUND_SERVICE
      ]),
      category:
          AndroidNotificationCategory.service, // Mark as service notification
      visibility:
          NotificationVisibility.public, // Ensure visibility in all modes
      enableLights: false, // Disable lights for persistent notifications
      enableVibration: false, // Disable vibration for persistent notifications
      playSound:
          false, // Disable sound for persistent notifications (they're updates)
      // Enhanced appearance properties
      ticker: '$title - $taskName',
      subText: subText,
      // Ensure it shows on lock screen
      fullScreenIntent: false, // Don't take over the screen
      timeoutAfter: null, // Never timeout
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      _kPersistentTimerNotificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: _kNotificationPayloadOpenApp, // Payload for opening the app
    );

    debugPrint(
      'DEBUG: Persistent Timer Notification Shown/Updated. Title: $title, Body: $body',
    );
  }

  /// Updates an existing persistent timer notification.
  Future<void> updatePersistentTimerNotification({
    required String taskName,
    required String timeRemaining,
    required String currentMode,
    required bool isRunning,
    required bool isFocusMode,
  }) async {
    // The implementation is largely the same as showing, but Flutter handles the update
    // if the ID is the same.
    await showPersistentTimerNotification(
      taskName: taskName,
      timeRemaining: timeRemaining,
      currentMode: currentMode,
      isRunning: isRunning,
      isFocusMode: isFocusMode,
    );
  }

  /// Cancels the persistent timer notification.
  Future<void> cancelPersistentTimerNotification() async {
    await _notificationsPlugin.cancel(_kPersistentTimerNotificationId);
    debugPrint('DEBUG: Persistent Timer Notification Cancelled.');
  }

  Future<void> playSound(String soundFileName) async {
    try {
      debugPrint(
        'DEBUG: NotificationService.playSound() called with sound: $soundFileName',
      );

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

      debugPrint('DEBUG: Processed asset path for sound: $assetPath');

      // Add a small delay to ensure the previous sound is fully stopped
      await Future.delayed(const Duration(milliseconds: 50));

      await _audioPlayer.play(AssetSource('sounds/$assetPath'));
      debugPrint('DEBUG: Sound played successfully: $soundFileName');

      // Add extra debugging for specific sounds
      if (soundFileName.contains('break_timer_start')) {
        debugPrint('DEBUG: *** BREAK TIMER SOUND SPECIFICALLY PLAYED ***');
      } else if (soundFileName.contains('progress_bar_full')) {
        debugPrint(
          'DEBUG: *** PROGRESS BAR FULL SOUND SPECIFICALLY PLAYED ***',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('DEBUG: Error playing sound $soundFileName: $e');
      debugPrint('DEBUG: Stack trace: $stackTrace');

      // Try alternative approach for problematic sounds
      if (soundFileName.contains('break_timer_start') ||
          soundFileName.contains('progress_bar_full')) {
        debugPrint('DEBUG: Attempting alternative playback for $soundFileName');
        try {
          await _audioPlayer.setSource(AssetSource('sounds/$soundFileName'));
          await _audioPlayer.resume();
          debugPrint(
            'DEBUG: Alternative playback successful for $soundFileName',
          );
        } catch (alternativeError) {
          debugPrint(
            'DEBUG: Alternative playback also failed: $alternativeError',
          );
        }
      }
    }
  }

  /// Plays a sound AND shows a notification for critical events (like timer completion)
  /// This ensures sounds are heard even when the app is minimized
  Future<void> playSoundWithNotification({
    required String soundFileName,
    required String title,
    required String body,
  }) async {
    debugPrint('DEBUG: Playing sound with notification - $title: $body');

    // First play the sound using the audio player
    await playSound(soundFileName);

    // Then show a notification with the same sound for background playback
    await showNotification(
      title: title,
      body: body,
      soundFileName: soundFileName,
      payload: 'sound_notification',
    );

    debugPrint('DEBUG: Sound notification shown for background playback');
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

    for (int i = 0; i < sounds.length; i++) {
      final sound = sounds[i];
      debugPrint('DEBUG: Testing sound ${i + 1}/${sounds.length}: $sound');
      await playSound(sound);
      await Future.delayed(
        const Duration(seconds: 2),
      ); // Wait longer between sounds
    }

    debugPrint('DEBUG: All sound tests completed');
  }

  // Enhanced comprehensive test for break timer sound specifically
  Future<void> testBreakTimerSoundExtensive() async {
    debugPrint('DEBUG: === EXTENSIVE BREAK TIMER SOUND TEST ===');

    // Test 1: Direct file path
    debugPrint('DEBUG: Test 1 - Direct file path');
    await playSound('break_timer_start.wav');
    await Future.delayed(const Duration(milliseconds: 1500));

    // Test 2: With sounds/ prefix
    debugPrint('DEBUG: Test 2 - With sounds/ prefix');
    await playSound('sounds/break_timer_start.wav');
    await Future.delayed(const Duration(milliseconds: 1500));

    // Test 3: With assets/sounds/ prefix
    debugPrint('DEBUG: Test 3 - With assets/sounds/ prefix');
    await playSound('assets/sounds/break_timer_start.wav');
    await Future.delayed(const Duration(milliseconds: 1500));

    debugPrint('DEBUG: === BREAK TIMER SOUND TEST COMPLETE ===');
  }

  // Test progress bar sound specifically
  Future<void> testProgressBarSoundExtensive() async {
    debugPrint('DEBUG: === EXTENSIVE PROGRESS BAR SOUND TEST ===');

    // Test 1: Direct file path
    debugPrint('DEBUG: Test 1 - Direct file path');
    await playSound('progress_bar_full.wav');
    await Future.delayed(const Duration(milliseconds: 1500));

    // Test 2: With sounds/ prefix
    debugPrint('DEBUG: Test 2 - With sounds/ prefix');
    await playSound('sounds/progress_bar_full.wav');
    await Future.delayed(const Duration(milliseconds: 1500));

    // Test 3: With assets/sounds/ prefix
    debugPrint('DEBUG: Test 3 - With assets/sounds/ prefix');
    await playSound('assets/sounds/progress_bar_full.wav');
    await Future.delayed(const Duration(milliseconds: 1500));

    debugPrint('DEBUG: === PROGRESS BAR SOUND TEST COMPLETE ===');
  }
}
