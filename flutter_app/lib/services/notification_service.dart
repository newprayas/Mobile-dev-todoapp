import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);

    if (kDebugMode) {
      debugPrint('DEBUG: NotificationService initialized');
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
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

    await _notificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }

  Future<void> playSound(String soundFileName) async {
    try {
      if (kDebugMode) {
        debugPrint(
          'DEBUG: NotificationService.playSound() called with sound: $soundFileName',
        );
      }
      await _audioPlayer.stop();

      // Ensure we use the correct asset path - remove any 'assets/' prefix
      String assetPath = soundFileName;
      if (assetPath.startsWith('assets/sounds/')) {
        assetPath = assetPath.substring(14); // Remove 'assets/sounds/' prefix
      } else if (assetPath.startsWith('assets/')) {
        assetPath = assetPath.substring(7); // Remove 'assets/' prefix
      } else if (assetPath.startsWith('sounds/')) {
        assetPath = assetPath.substring(7); // Remove 'sounds/' prefix
      }

      if (kDebugMode) {
        debugPrint('DEBUG: Processed asset path: $assetPath');
      }

      // AssetSource expects just the filename since we declared 'assets/sounds/' in pubspec.yaml
      await _audioPlayer.play(AssetSource('sounds/$assetPath'));
      if (kDebugMode) {
        debugPrint('DEBUG: Sound played successfully: $soundFileName');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('DEBUG: Error playing sound $soundFileName: $e');
        debugPrint('DEBUG: Stack trace: $stackTrace');
      }
    }
  }

  // Enhanced test method with individual sound testing
  Future<void> testBreakSound() async {
    if (kDebugMode) {
      debugPrint('DEBUG: Testing BREAK TIMER sound specifically...');
      debugPrint('DEBUG: Sound file path: break_timer_start.wav');
      await playSound('break_timer_start.wav');
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('DEBUG: Break timer sound test completed');
    }
  }

  // Immediate break sound test without delays
  Future<void> testBreakSoundImmediate() async {
    if (kDebugMode) {
      debugPrint('DEBUG: IMMEDIATE break timer sound test...');
      try {
        await playSound('break_timer_start.wav');
        debugPrint('DEBUG: IMMEDIATE break timer sound succeeded');
      } catch (e) {
        debugPrint('DEBUG: IMMEDIATE break timer sound failed: $e');
      }
    }
  }

  // Test method to verify sound files work
  Future<void> testAllSounds() async {
    if (kDebugMode) {
      debugPrint('DEBUG: Testing all sound files...');

      final sounds = [
        'break_timer_start.wav',
        'focus_timer_start.wav',
        'progress_bar_full.wav',
      ];

      for (final sound in sounds) {
        debugPrint('DEBUG: Testing sound: $sound');
        await playSound(sound);
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Brief pause between sounds
      }

      debugPrint('DEBUG: All sound tests completed');
    }
  }
}
