import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/auth_wrapper.dart';
import 'features/pomodoro/providers/timer_provider.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
