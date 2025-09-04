import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async'; // For Timer
import 'core/theme/app_colors.dart';
import 'core/widgets/auth_wrapper.dart';
import 'features/pomodoro/providers/timer_provider.dart';
import 'core/bridge/notification_action_dispatcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/utils/debug_logger.dart';

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
      logger.i(
        "App Dispatcher: Delivering action='$actionId' DIRECTLY to TimerNotifier.",
      );
      ref.read(timerProvider.notifier).handleNotificationAction(actionId);
      return true;
    });
    // Poll for background-isolate persisted actions (fallback path).
    _actionPoller = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _flushPendingAction();
    });
  }

  /// Flush any pending notification action persisted by the background isolate.
  Future<void> _flushPendingAction() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? action = prefs.getString('last_notification_action');
      if (action != null) {
        debugPrint('APP_FLUSH: Detected and processing pending action=$action');
        await ref.read(timerProvider.notifier).handleNotificationAction(action);
        await prefs.remove('last_notification_action');
      }
    } catch (e) {
      debugPrint('APP_FLUSH: Error flushing pending action: $e');
    }
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
      // Immediately flush any pending background actions on resume for responsiveness.
      _flushPendingAction();
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
        await _flushPendingAction();
        _initialActionFlushed = true;
      });
    }

    // Legacy notificationActionProvider listener removed: actions now dispatched directly.
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
