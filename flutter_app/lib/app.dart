import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async'; // For Timer
import 'core/theme/app_colors.dart';
import 'core/widgets/auth_wrapper.dart';
import 'features/pomodoro/providers/timer_provider.dart';
import 'core/providers/notification_action_provider.dart';
import 'core/bridge/notification_action_dispatcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  bool _initialActionFlushed = false;
  Timer? _actionPoller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Register dispatcher so main.dart callback can deliver actions immediately.
    registerNotificationActionDispatcher((String actionId) {
      debugPrint('APP_DISPATCHER: delivering action=$actionId to provider');
      ref.read(notificationActionProvider.notifier).state = actionId;
      return true; // Indicate handled
    });
    // Poll for background-isolate persisted actions (fallback path).
    _actionPoller = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? last = prefs.getString('last_notification_action');
        if (last != null) {
          debugPrint('APP_POLLER: detected pending action=$last');
          ref.read(notificationActionProvider.notifier).state = last;
          await prefs.remove('last_notification_action');
        }
      } catch (_) {
        // Silent catch; polling continues.
      }
    });
  }

  @override
  void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  clearNotificationActionDispatcher();
  _actionPoller?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final notifier = ref.read(timerProvider.notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App going to background: schedule Workmanager task to persist timer
      notifier.scheduleBackgroundPersistence();
    } else if (state == AppLifecycleState.resumed) {
      // App returned to foreground: cancel background job
      notifier.cancelBackgroundPersistence();
    }
  }

  @override
  Widget build(BuildContext context) {
    // One-time flush of any pending action captured before dispatcher registration.
    if (!_initialActionFlushed) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_initialActionFlushed) return; // Guard
        final prefs = await SharedPreferences.getInstance();
        final String? last = prefs.getString('last_notification_action');
        if (last != null) {
          debugPrint('APP_INIT: flushing persisted notification action=$last');
          ref.read(notificationActionProvider.notifier).state = last;
          await prefs.remove('last_notification_action');
        }
        _initialActionFlushed = true;
      });
    }

    // Listen to action provider changes and route to TimerNotifier
    ref.listen<String?>(notificationActionProvider, (prev, next) {
      if (next != null) {
        debugPrint('APP_LISTENER: handling notification action=$next');
        ref.read(timerProvider.notifier).handleNotificationAction(next);
        // Clear to avoid replay
        ref.read(notificationActionProvider.notifier).state = null;
      }
    });
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
