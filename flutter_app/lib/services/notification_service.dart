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
      // The asset path is relative to the project root, as defined in pubspec.yaml
      final assetPath = 'sounds/$soundFileName';
      await _audioPlayer.play(AssetSource(assetPath));
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
      debugPrint('DEBUG: Sound file path: sounds/Break timer start.wav');
      await playSound('sounds/Break timer start.wav');
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('DEBUG: Break timer sound test completed');
    }
  }

  // Immediate break sound test without delays
  Future<void> testBreakSoundImmediate() async {
    if (kDebugMode) {
      debugPrint('DEBUG: IMMEDIATE break timer sound test...');
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.play(AssetSource('sounds/Break timer start.wav'));
        debugPrint('DEBUG: IMMEDIATE break timer sound executed');
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
        'sounds/Break timer start.wav',
        'sounds/Focus timer start.wav',
        'sounds/progress bar full.wav',
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
