import 'package:flutter/material.dart';
import 'dart:io'
    show Platform, HttpClient; // Added HttpClient for backend readiness check
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/services/api_service.dart';
import 'core/theme/app_colors.dart';
import 'core/services/notification_service.dart';
import 'core/widgets/auth_wrapper.dart';
import 'features/todo/providers/todos_provider.dart';
import 'core/providers/notification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService();
  await notificationService.init();

  // Test break timer sound on app startup (debug only)
  if (kDebugMode) {
    debugPrint('MAIN: Testing break timer sound on startup...');
    try {
      await notificationService.testBreakSound();
    } catch (e) {
      debugPrint('MAIN: Break sound test failed: $e');
    }
  }

  // Allow overriding the API host at build/run time with --dart-define=API_BASE_URL
  const envBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  String chooseBaseUrl() {
    if (envBase.isNotEmpty) return envBase;
    // Android emulator -> host machine is reachable at 10.0.2.2
    if (Platform.isAndroid) return 'http://10.0.2.2:5000';
    // iOS simulator and other platforms can use localhost
    return 'http://127.0.0.1:5000';
  }

  final baseUrl = chooseBaseUrl();
  // show chosen base for easier debugging during development
  if (kDebugMode) debugPrint('Using API baseUrl: $baseUrl');

  // Dev-only: wait briefly for backend readiness (helps avoid connection refused race)
  await _waitForBackend(baseUrl, attempts: 8, delayMs: 400);

  final api = ApiService(baseUrl);

  runApp(
    ProviderScope(
      overrides: [
        // Override the API service provider with our instance
        apiServiceProvider.overrideWithValue(api),
        // Override notification service provider
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const MyApp(),
    ),
  );
}

// Simple readiness / liveness wait loop for local backend. Will not throw;
// it only logs status to avoid blocking app start indefinitely.
Future<void> _waitForBackend(
  String baseUrl, {
  int attempts = 5,
  int delayMs = 500,
}) async {
  final lower = baseUrl.toLowerCase();
  final isLocal =
      lower.contains('127.0.0.1') ||
      lower.contains('localhost') ||
      lower.contains('10.0.2.2');
  if (!isLocal) return; // Only applicable for local dev
  if (kDebugMode) {
    debugPrint('BACKEND WAIT: Checking backend readiness at $baseUrl');
  }
  final uri = Uri.parse('$baseUrl/health');
  for (var i = 1; i <= attempts; i++) {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('BACKEND WAIT: Backend healthy (attempt $i/$attempts).');
        }
        client.close(force: true);
        return;
      } else {
        if (kDebugMode) {
          debugPrint(
            'BACKEND WAIT: Unexpected status ${resp.statusCode} (attempt $i/$attempts)',
          );
        }
      }
      client.close(force: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BACKEND WAIT: attempt $i/$attempts failed: $e');
      }
    }
    await Future.delayed(Duration(milliseconds: delayMs));
  }
  if (kDebugMode) {
    debugPrint(
      'BACKEND WAIT: Proceeding without positive health confirmation.',
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Todo Flutter',
      theme: ThemeData.dark().copyWith(
        primaryColor: AppColors.brightYellow,
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ).apply(bodyColor: AppColors.lightGray),
      ),
      home: const AuthWrapper(),
    );
  }
}
