// Focus Timer App - Main Entry Point
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import the services package
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'core/utils/app_constants.dart';
import 'core/data/app_database.dart';
import 'core/data/todo_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart'; // Import the new root widget
import 'core/services/mock_api_service.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'core/debug/notification_sound_tester.dart';
import 'core/providers/notification_provider.dart';
import 'core/utils/debug_logger.dart';
import 'core/utils/helpers.dart'; // Import formatTime
import 'features/pomodoro/notifications/persistent_timer_notification_model.dart';
import 'features/pomodoro/models/timer_state.dart';
import 'features/todo/models/todo.dart';

// Define actualApiService globally so it's accessible to Workmanager for initial config saving
late final ApiService actualApiService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the orientation to portrait mode
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final notificationService = NotificationService();
  await notificationService.init();

  // Assign the foreground notification tap handler
  notificationService.onNotificationTap = (String? payload) {
    if (payload == 'open_app') {
      // Logic to bring the app to foreground if needed.
      // For Flutter, simply handling the payload and potentially navigating
      // in the main app is usually enough; the OS will bring the app forward.
      debugLog(
        'MAIN',
        'Notification tapped, app will be brought to foreground.',
      );
    } else if (payload == 'pause_resume_timer') {
      // Handle pause/resume action from notification
      debugLog('MAIN', 'Notification pause/resume action triggered');
      // We'll handle this in the app widget by listening to a provider
      // For now, just log it
    } else if (payload == 'stop_timer') {
      // Handle stop action from notification
      debugLog('MAIN', 'Notification stop action triggered');
      // We'll handle this in the app widget by listening to a provider
      // For now, just log it
    } else if (payload != null && payload.startsWith('toggle_')) {
      // This is a placeholder. Real implementation needs a way to communicate
      // with the active TimerNotifier in the foreground or trigger a WM task.
      debugLog('MAIN', 'Foreground notification action: $payload');
      // A more robust solution might use a local event bus or a simple shared pref flag
      // that the TimerNotifier listens to. For now, we'll focus on background handling.
    }
  };

  // Test break timer sound on app startup (debug only)
  if (kDebugMode) {
    final tester = NotificationSoundTester(notificationService);
    await tester.testBreakSound();
  }

  // Allow overriding the API host at build/run time with --dart-define=API_BASE_URL
  const envBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  String chooseBaseUrl() {
    if (envBase.isNotEmpty) return envBase;
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000'; // Use 10.0.2.2 for Android emulator to reach host localhost
    }
    return 'http://127.0.0.1:5000';
  }

  final baseUrl = chooseBaseUrl();
  // show chosen base for easier debugging during development
  debugLog('MAIN', 'Using API baseUrl: $baseUrl');

  // Decide whether to use real ApiService or MockApiService based on debug mode
  actualApiService = kDebugMode
      ? MockApiService(baseUrl)
      : ApiService(baseUrl); // Explicitly type as ApiService

  // Initialize Workmanager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
  // This periodic task is mainly for ensuring Workmanager is active and can sometimes
  // act as a fallback, but primary timer updates will use one-off tasks.
  Workmanager().registerPeriodicTask(
    AppConstants.pomodoroTimerTask,
    AppConstants.pomodoroTimerTask,
    frequency: const Duration(minutes: 15), // Minimum allowed frequency
    initialDelay: const Duration(seconds: 10),
    constraints: Constraints(networkType: NetworkType.notRequired),
  );

  runApp(
    ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(actualApiService),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const App(),
    ),
  );
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final NotificationService notificationService = NotificationService();
    await notificationService.init();

    debugLog('BackgroundTimer', 'Executing workmanager task: $task');

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve API config saved by TimerNotifier
    final String? savedApiBaseUrl = prefs.getString(
      AppConstants.prefApiBaseUrl,
    );
    final bool? savedIsDebugMode = prefs.getBool(AppConstants.prefIsDebugMode);

    if (savedApiBaseUrl == null || savedIsDebugMode == null) {
      debugLog(
        'BackgroundTimer',
        'Missing API config in preferences. Cannot initialize ApiService. Exiting.',
      );
      return Future.value(true);
    }

    // Re-instantiate ApiService and AppDatabase for background tasks
    final ApiService backgroundApiService = savedIsDebugMode
        ? MockApiService(savedApiBaseUrl)
        : ApiService(savedApiBaseUrl);
    final AppDatabase db = AppDatabase();
    final TodoRepository todoRepository = TodoRepository(
      db,
      backgroundApiService,
    );

    try {
      if (task == AppConstants.pomodoroTimerTask) {
        final int? activeTaskIdRaw = prefs.getInt(
          AppConstants.prefActiveTaskId,
        );
        final String? activeTaskText = prefs.getString(
          AppConstants.prefActiveTaskText,
        );
        int timeRemaining = prefs.getInt(AppConstants.prefTimeRemaining) ?? 0;
        bool isRunning = prefs.getBool(AppConstants.prefIsRunning) ?? false;
        final String currentMode =
            prefs.getString(AppConstants.prefCurrentMode) ?? 'focus';
        final int plannedDurationSeconds =
            prefs.getInt(AppConstants.prefPlannedDurationSeconds) ?? 0;
        final int focusDurationSeconds =
            prefs.getInt(AppConstants.prefFocusDurationSeconds) ?? 0;
        final int breakDurationSeconds =
            prefs.getInt(AppConstants.prefBreakDurationSeconds) ?? 0;
        int currentCycle = prefs.getInt(AppConstants.prefCurrentCycle) ?? 1;
        final int totalCycles = prefs.getInt(AppConstants.prefTotalCycles) ?? 1;
        int completedSessions =
            prefs.getInt(AppConstants.prefCompletedSessions) ?? 0;
        final int? backgroundStartTime = prefs.getInt(
          AppConstants.prefBackgroundStartTime,
        );
        final bool isPermanentlyOverdue =
            prefs.getBool(AppConstants.prefIsPermanentlyOverdue) ?? false;

        final String? focusedTimeCacheJson = prefs.getString(
          AppConstants.prefFocusedTimeCache,
        );
        final Map<int, int> focusedTimeCache = focusedTimeCacheJson != null
            ? Map<String, int>.from(
                json.decode(focusedTimeCacheJson),
              ).map((k, v) => MapEntry(int.parse(k), v))
            : {};

        // Only proceed if there's an active running task
        if (activeTaskIdRaw == null || activeTaskIdRaw == -1 || !isRunning) {
          debugLog(
            'BackgroundTimer',
            'No active/running timer in background or invalid task ID. Cancelling Workmanager task and persistent notification.',
          );
          await Workmanager().cancelByUniqueName(
            AppConstants.pomodoroTimerTask,
          );
          await prefs.setBool(AppConstants.prefSessionScheduled, false);
          await notificationService
              .cancelPersistentTimerNotification(); // Clear notification
          return Future.value(true);
        }

        final int activeTaskId = activeTaskIdRaw;

        // Calculate elapsed time since app went to background if timer was running
        if (backgroundStartTime != null) {
          final int now = DateTime.now().millisecondsSinceEpoch;
          final int elapsedSinceBackground =
              (now - backgroundStartTime) ~/ 1000;
          timeRemaining -= elapsedSinceBackground;

          // Update focused time for the active task
          focusedTimeCache[activeTaskId] =
              (focusedTimeCache[activeTaskId] ?? 0) + elapsedSinceBackground;
          await prefs.setString(
            AppConstants.prefFocusedTimeCache,
            json.encode(
              focusedTimeCache.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }

        debugLog(
          'BackgroundTimer',
          'Task: $activeTaskText, Mode: $currentMode, Remaining: $timeRemaining s, Focused: ${focusedTimeCache[activeTaskId]} s',
        );

        // Update persistent notification
        final pseudoState = TimerState(
          activeTaskId: activeTaskId,
          activeTaskName: activeTaskText,
          timeRemaining: timeRemaining.clamp(0, double.infinity).toInt(),
          isRunning: isRunning,
          isTimerActive: true,
          currentMode: currentMode,
          focusDurationSeconds: focusDurationSeconds,
          breakDurationSeconds: breakDurationSeconds,
          currentCycle: currentCycle,
          totalCycles: totalCycles,
          completedSessions: completedSessions,
          isProgressBarFull: isProgressBarFull,
          allSessionsComplete: allSessionsComplete,
          overdueSessionsComplete: overdueSessionsComplete,
          overdueCrossedTaskId: overdueCrossedTaskId,
          overduePromptShown: overduePromptShown,
          overdueContinued: overdueContinued,
          focusedTimeCache: focusedTimeCache,
          suppressNextActivation: suppressNextActivation,
          cycleOverflowBlocked: cycleOverflowBlocked,
          isPermanentlyOverdue: isPermanentlyOverdue,
          backgroundStartTime: backgroundStartTime,
          pausedTimeTotal: pausedTimeTotal,
        );
        final model = PersistentTimerNotificationModel.fromState(
          state: pseudoState,
          activeTodo: activeTaskId != null
              ? Todo(
                  id: activeTaskId,
                  userId: '',
                  text: activeTaskText ?? 'Unknown Task',
                  completed: false,
                  durationHours: 0,
                  durationMinutes: 0,
                  focusedTime: focusedTimeCache[activeTaskId] ?? 0,
                  wasOverdue: isPermanentlyOverdue ? 1 : 0,
                  overdueTime: 0,
                  createdAt: DateTime.now(),
                )
              : null,
        );
        await notificationService.showOrUpdatePersistent(
          title: model.title,
          body: model.body,
          actionIds: model.actionIds,
        );

        if (timeRemaining <= 0) {
          // Phase completed in background
          if (currentMode == 'focus') {
            completedSessions++;
            // Persist focused time to DB before showing completion
            await todoRepository.updateFocusTime(
              activeTaskId,
              focusedTimeCache[activeTaskId] ?? 0,
            );

            if (completedSessions >= totalCycles) {
              if (isPermanentlyOverdue) {
                debugLog(
                  'BackgroundTimer',
                  'Overdue task session complete in background!',
                );
                await notificationService.playSound('progress_bar_full.wav');
                await notificationService.showNotification(
                  title: 'Overdue Session Complete!',
                  body:
                      'Your overdue session for "$activeTaskText" is complete.',
                );
                await prefs.setBool(
                  AppConstants.prefOverdueSessionsComplete,
                  true,
                );
              } else {
                debugLog(
                  'BackgroundTimer',
                  'All focus sessions complete in background!',
                );
                await notificationService.playSound('progress_bar_full.wav');
                await notificationService.showNotification(
                  title: 'All Sessions Complete!',
                  body:
                      'You have completed all $totalCycles focus sessions for "$activeTaskText"!',
                );
                await prefs.setBool(AppConstants.prefAllSessionsComplete, true);
              }
              // End of all sessions, clear everything
              await Workmanager().cancelByUniqueName(
                AppConstants.pomodoroTimerTask,
              );
              await prefs.setBool(AppConstants.prefSessionScheduled, false);
              await prefs.remove(AppConstants.prefActiveTaskId);
              await prefs.remove(AppConstants.prefActiveTaskText);
              await prefs.setBool(AppConstants.prefIsRunning, false);
              await notificationService
                  .cancelPersistentTimerNotification(); // Clear notification
            } else {
              // Move to break session
              await notificationService.playSound('break_timer_start.wav');
              await notificationService.showNotification(
                title: 'Focus Session Complete!',
                body: 'Time for a break for "$activeTaskText".',
              );
              currentCycle++;
              timeRemaining = breakDurationSeconds;
              await prefs.setString(AppConstants.prefCurrentMode, 'break');
              await prefs.setInt(AppConstants.prefTimeRemaining, timeRemaining);
              await prefs.setInt(AppConstants.prefCurrentCycle, currentCycle);
              await prefs.setInt(
                AppConstants.prefCompletedSessions,
                completedSessions,
              );
              await prefs.setInt(
                AppConstants.prefBackgroundStartTime,
                DateTime.now().millisecondsSinceEpoch,
              ); // Reset start time
            }
          } else if (currentMode == 'break') {
            // Move to focus session
            await notificationService.playSound('focus_timer_start.wav');
            await notificationService.showNotification(
              title: 'Break Complete!',
              body: 'Time to focus on "$activeTaskText" again!',
            );
            timeRemaining = focusDurationSeconds;
            await prefs.setString(AppConstants.prefCurrentMode, 'focus');
            await prefs.setInt(AppConstants.prefTimeRemaining, timeRemaining);
            await prefs.setInt(
              AppConstants.prefBackgroundStartTime,
              DateTime.now().millisecondsSinceEpoch,
            ); // Reset start time
          }
          // After a phase transition, re-schedule Workmanager for the new phase
          if (prefs.getBool(AppConstants.prefIsRunning) ?? false) {
            // Check if still running
            await Workmanager().registerOneOffTask(
              AppConstants.pomodoroTimerTask,
              AppConstants.pomodoroTimerTask,
              initialDelay: Duration(
                seconds: timeRemaining.clamp(1, double.infinity).toInt() + 5,
              ), // Reschedule for new remaining time
              existingWorkPolicy: ExistingWorkPolicy.replace,
              inputData: {
                'apiBaseUrl': savedApiBaseUrl,
                'isDebugMode': savedIsDebugMode,
              },
            );
            await prefs.setBool(AppConstants.prefSessionScheduled, true);
          } else {
            // If timer stopped due to completion or external stop
            await Workmanager().cancelByUniqueName(
              AppConstants.pomodoroTimerTask,
            );
            await prefs.setBool(AppConstants.prefSessionScheduled, false);
            await notificationService.cancelPersistentTimerNotification();
          }
        } else {
          // Timer is still running, update remaining time and background start time
          await prefs.setInt(AppConstants.prefTimeRemaining, timeRemaining);
          await prefs.setInt(
            AppConstants.prefBackgroundStartTime,
            DateTime.now().millisecondsSinceEpoch,
          );

          // Check for overdue crossing in background
          if (!isPermanentlyOverdue &&
              currentMode == 'focus' &&
              plannedDurationSeconds > 0 &&
              (focusedTimeCache[activeTaskId] ?? 0) >= plannedDurationSeconds &&
              (prefs.getInt(AppConstants.prefOverdueCrossedTaskId) !=
                  activeTaskId)) {
            debugLog(
              'BackgroundTimer',
              'Task "$activeTaskText" crossed planned duration in background!',
            );
            await notificationService.playSound('progress_bar_full.wav');
            await notificationService.showNotification(
              title: 'Planned Time Complete!',
              body:
                  'Time for "$activeTaskText" is up. Decide whether to continue or complete when you open the app.',
            );
            await prefs.setInt(
              AppConstants.prefOverdueCrossedTaskId,
              activeTaskId,
            );
            await prefs.setBool(
              AppConstants.prefIsRunning,
              false,
            ); // Mark as not running for background logic
            // The main app will handle the prompt. No need to clear workmanager here,
            // let it complete this cycle and the UI will then clear/reschedule.
          }
          // Reschedule Workmanager for the next tick to ensure continuous background updates
          await Workmanager().registerOneOffTask(
            AppConstants.pomodoroTimerTask,
            AppConstants.pomodoroTimerTask,
            initialDelay: const Duration(seconds: 1), // Tick every second
            existingWorkPolicy: ExistingWorkPolicy.replace,
            inputData: {
              'apiBaseUrl': savedApiBaseUrl,
              'isDebugMode': savedIsDebugMode,
            },
          );
          await prefs.setBool(AppConstants.prefSessionScheduled, true);
        }
      }
      return Future.value(true);
    } catch (e, st) {
      debugLog('BackgroundTimer', 'Error in callbackDispatcher: $e\n$st');
      return Future.value(false);
    } finally {
      await db.close();
    }
  });
}
