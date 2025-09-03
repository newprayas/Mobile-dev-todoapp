import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:workmanager/workmanager.dart';
import '../../../core/utils/app_constants.dart';
import '../models/timer_state.dart';
import '../services/timer_persistence_manager.dart';

/// Handles scheduling/canceling background tasks for the Pomodoro timer.
class TimerBackgroundScheduler {
  final TimerPersistenceManager persistenceManager;
  final Logger logger = Logger();

  TimerBackgroundScheduler(this.persistenceManager);

  Future<void> scheduleSession({
    required TimerState state,
    required String apiBaseUrl,
    required bool isDebugMode,
    required int remainingSeconds,
  }) async {
    if (remainingSeconds <= 0 ||
        !state.isRunning ||
        state.activeTaskId == null) {
      await cancelSession();
      return;
    }

    await cancelSession();
    await persistenceManager.saveApiConfig(apiBaseUrl, isDebugMode);
    await persistenceManager.saveTimerState(state);

    final int delaySeconds = remainingSeconds + 5; // buffer
    logger.i('[TimerBackgroundScheduler] Scheduling in $delaySeconds s');

    await Workmanager().registerOneOffTask(
      AppConstants.pomodoroTimerTask,
      AppConstants.pomodoroTimerTask,
      initialDelay: Duration(seconds: delaySeconds),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresCharging: false,
        requiresBatteryNotLow: false,
      ),
      inputData: _buildInputData(
        state,
        apiBaseUrl,
        isDebugMode,
        remainingSeconds,
      ),
    );
    await persistenceManager.setSessionScheduled(true);
  }

  Future<void> cancelSession() async {
    await Workmanager().cancelByUniqueName(AppConstants.pomodoroTimerTask);
    await persistenceManager.setSessionScheduled(false);
  }

  Map<String, dynamic> _buildInputData(
    TimerState state,
    String apiBaseUrl,
    bool isDebugMode,
    int remainingSeconds,
  ) {
    return {
      'apiBaseUrl': apiBaseUrl,
      'isDebugMode': isDebugMode,
      'activeTaskId': state.activeTaskId,
      'activeTaskText': state.activeTaskName,
      'timeRemaining': remainingSeconds,
      'currentMode': state.currentMode,
      'focusedTimeCache': json.encode(
        state.focusedTimeCache.map((k, v) => MapEntry(k.toString(), v)),
      ),
      'plannedDurationSeconds': state.plannedDurationSeconds ?? 0,
      'focusDurationSeconds': state.focusDurationSeconds ?? 0,
      'breakDurationSeconds': state.breakDurationSeconds ?? 0,
      'currentCycle': state.currentCycle,
      'totalCycles': state.totalCycles,
      'completedSessions': state.completedSessions,
      'isPermanentlyOverdue': state.isPermanentlyOverdue,
    };
  }
}
