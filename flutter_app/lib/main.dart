// Focus Timer App - Main Entry Point
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import the services package
import 'dart:io' show Platform; // Added HttpClient for backend readiness check
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart'; // Import the new root widget
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'features/todo/providers/todos_provider.dart';
import 'core/providers/notification_provider.dart';
import 'core/utils/debug_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the orientation to portrait mode
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final notificationService = NotificationService();
  await notificationService.init();

  // Test break timer sound on app startup (debug only)
  if (kDebugMode) {
    debugLog('MAIN', 'Testing break timer sound on startup...');
    try {
      await notificationService.testBreakSound();
    } catch (e) {
      debugLog('MAIN', 'Break sound test failed: $e');
    }
  }

  // Allow overriding the API host at build/run time with --dart-define=API_BASE_URL
  const envBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  String chooseBaseUrl() {
    if (envBase.isNotEmpty) return envBase;
    // For both Android emulator and physical devices with `adb reverse`,
    // the host machine is reachable at 127.0.0.1 on the device.
    if (Platform.isAndroid) return 'http://127.0.0.1:5000';
    // iOS simulator and other platforms can use localhost
    return 'http://127.0.0.1:5000';
  }

  final baseUrl = chooseBaseUrl();
  // show chosen base for easier debugging during development
  if (kDebugMode) debugLog('MAIN', 'Using API baseUrl: $baseUrl');

  final api = ApiService(baseUrl);

  runApp(
    ProviderScope(
      overrides: [
        // Override the API service provider with our instance
        apiServiceProvider.overrideWithValue(api),
        // Override notification service provider
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const App(), // Run the new App widget
    ),
  );
}
