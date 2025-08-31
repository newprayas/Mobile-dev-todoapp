// lib/core/utils/app_constants.dart

/// A collection of constants used across the application for keys,
/// task names, and other fixed values.
class AppConstants {
  // Workmanager task identifiers
  static const String pomodoroTimerTask = 'pomodoroTimerTask';

  // SharedPreferences keys for timer state persistence
  static const String prefActiveTaskId = 'activeTaskId';
  static const String prefActiveTaskText =
      'activeTaskText'; // For notifications in background
  static const String prefTimeRemaining = 'timeRemaining';
  static const String prefIsRunning = 'isRunning';
  static const String prefIsTimerActive = 'isTimerActive'; // NEW
  static const String prefCurrentMode = 'currentMode';
  static const String prefPlannedDurationSeconds = 'plannedDurationSeconds';
  static const String prefFocusDurationSeconds = 'focusDurationSeconds';
  static const String prefBreakDurationSeconds = 'breakDurationSeconds';
  static const String prefCurrentCycle = 'currentCycle';
  static const String prefTotalCycles = 'totalCycles';
  static const String prefCompletedSessions = 'completedSessions';
  static const String prefIsProgressBarFull = 'isProgressBarFull'; // NEW
  static const String prefAllSessionsComplete = 'allSessionsComplete'; // NEW
  static const String prefOverdueSessionsComplete =
      'overdueSessionsComplete'; // NEW
  static const String prefOverdueCrossedTaskId =
      'overdueCrossedTaskId'; // When overdue was crossed
  static const String prefOverdueCrossedTaskName =
      'overdueCrossedTaskName'; // NEW
  static const String prefOverduePromptShown =
      'overduePromptShown'; // Set of IDs
  static const String prefOverdueContinued = 'overdueContinued'; // Set of IDs
  static const String prefFocusedTimeCache =
      'focusedTimeCache'; // Store as JSON string
  static const String prefSuppressNextActivation =
      'suppressNextActivation'; // NEW
  static const String prefCycleOverflowBlocked = 'cycleOverflowBlocked'; // NEW
  static const String prefIsPermanentlyOverdue = 'isPermanentlyOverdue';

  // Background timer state for persistence
  static const String prefBackgroundStartTime = 'backgroundStartTime';
  static const String prefPausedTimeTotal = 'pausedTimeTotal';
  static const String prefWasInBackground = 'wasInBackground';
  static const String prefSessionScheduled =
      'sessionScheduled'; // NEW: Track if a WM task is active

  // ApiService configuration for background isolate
  static const String prefApiBaseUrl = 'apiBaseUrl';
  static const String prefIsDebugMode = 'isDebugMode';

  // Notification channel ID
  static const String notificationChannelId = 'pomodoro_channel';
  static const String notificationChannelName = 'Pomodoro Notifications';
  static const String notificationChannelDescription =
      'Notifications for Pomodoro timer events';
}
