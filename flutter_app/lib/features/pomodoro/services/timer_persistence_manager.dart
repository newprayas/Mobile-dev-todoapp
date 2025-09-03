import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/debug_logger.dart';
import '../../../core/utils/app_constants.dart';
import '../models/timer_state.dart';

/// Handles persistence of [TimerState] to and from [SharedPreferences].
///
/// Isolated from the notifier so that persistence concerns are testable and
/// replaceable (e.g. migrate to another storage) without touching timer logic.
class TimerPersistenceManager {
  final SharedPreferences _prefs;
  TimerPersistenceManager(this._prefs);

  Future<void> saveTimerState(TimerState state) async {
    await _prefs.setInt(AppConstants.prefActiveTaskId, state.activeTaskId ?? -1);
    await _prefs.setString(AppConstants.prefActiveTaskText, state.activeTaskName ?? '');
    await _prefs.setInt(AppConstants.prefTimeRemaining, state.timeRemaining);
    await _prefs.setBool(AppConstants.prefIsRunning, state.isRunning);
    await _prefs.setBool(AppConstants.prefIsTimerActive, state.isTimerActive);
    await _prefs.setString(AppConstants.prefCurrentMode, state.currentMode);
    await _prefs.setInt(AppConstants.prefPlannedDurationSeconds, state.plannedDurationSeconds ?? 0);
    await _prefs.setInt(AppConstants.prefFocusDurationSeconds, state.focusDurationSeconds ?? 0);
    await _prefs.setInt(AppConstants.prefBreakDurationSeconds, state.breakDurationSeconds ?? 0);
    await _prefs.setInt(AppConstants.prefCurrentCycle, state.currentCycle);
    await _prefs.setInt(AppConstants.prefTotalCycles, state.totalCycles);
    await _prefs.setInt(AppConstants.prefCompletedSessions, state.completedSessions);
    await _prefs.setBool(AppConstants.prefIsProgressBarFull, state.isProgressBarFull);
    await _prefs.setBool(AppConstants.prefAllSessionsComplete, state.allSessionsComplete);
    await _prefs.setBool(AppConstants.prefOverdueSessionsComplete, state.overdueSessionsComplete);
    await _prefs.setInt(AppConstants.prefOverdueCrossedTaskId, state.overdueCrossedTaskId ?? -1);
    await _prefs.setString(AppConstants.prefOverdueCrossedTaskName, state.overdueCrossedTaskName ?? '');
    await _prefs.setStringList(AppConstants.prefOverduePromptShown, state.overduePromptShown.map((e) => e.toString()).toList());
    await _prefs.setStringList(AppConstants.prefOverdueContinued, state.overdueContinued.map((e) => e.toString()).toList());
    final Map<String, int> focusedTimeCacheStringKeys = state.focusedTimeCache.map((k, v) => MapEntry(k.toString(), v));
    await _prefs.setString(AppConstants.prefFocusedTimeCache, json.encode(focusedTimeCacheStringKeys));
    await _prefs.setBool(AppConstants.prefSuppressNextActivation, state.suppressNextActivation);
    await _prefs.setBool(AppConstants.prefCycleOverflowBlocked, state.cycleOverflowBlocked);
    await _prefs.setBool(AppConstants.prefIsPermanentlyOverdue, state.isPermanentlyOverdue);
    await _prefs.setInt(AppConstants.prefBackgroundStartTime, state.backgroundStartTime ?? 0);
    await _prefs.setInt(AppConstants.prefPausedTimeTotal, state.pausedTimeTotal);
    await _prefs.setBool(AppConstants.prefWasInBackground, state.wasInBackground);
    debugLog('TimerPersistenceManager', 'TimerState saved: ${state.toString()}');
  }

  TimerState? loadTimerState() {
    final int? activeTaskIdRaw = _prefs.getInt(AppConstants.prefActiveTaskId);
    if (activeTaskIdRaw == null || activeTaskIdRaw == -1) return null; // Nothing persisted

    final String? cacheJson = _prefs.getString(AppConstants.prefFocusedTimeCache);
    final Map<int, int> focusedTimeCache = cacheJson != null
        ? Map<String, int>.from(json.decode(cacheJson)).map((k, v) => MapEntry(int.parse(k), v))
        : {};

    final loaded = TimerState(
      activeTaskId: activeTaskIdRaw,
      activeTaskName: _prefs.getString(AppConstants.prefActiveTaskText),
      timeRemaining: _prefs.getInt(AppConstants.prefTimeRemaining) ?? 0,
      isRunning: _prefs.getBool(AppConstants.prefIsRunning) ?? false,
      isTimerActive: _prefs.getBool(AppConstants.prefIsTimerActive) ?? false,
      currentMode: _prefs.getString(AppConstants.prefCurrentMode) ?? 'focus',
      plannedDurationSeconds: _prefs.getInt(AppConstants.prefPlannedDurationSeconds) ?? 0,
      focusDurationSeconds: _prefs.getInt(AppConstants.prefFocusDurationSeconds) ?? 0,
      breakDurationSeconds: _prefs.getInt(AppConstants.prefBreakDurationSeconds) ?? 0,
      currentCycle: _prefs.getInt(AppConstants.prefCurrentCycle) ?? 1,
      totalCycles: _prefs.getInt(AppConstants.prefTotalCycles) ?? 1,
      completedSessions: _prefs.getInt(AppConstants.prefCompletedSessions) ?? 0,
      isProgressBarFull: _prefs.getBool(AppConstants.prefIsProgressBarFull) ?? false,
      allSessionsComplete: _prefs.getBool(AppConstants.prefAllSessionsComplete) ?? false,
      overdueSessionsComplete: _prefs.getBool(AppConstants.prefOverdueSessionsComplete) ?? false,
      overdueCrossedTaskId: _prefs.getInt(AppConstants.prefOverdueCrossedTaskId) == -1 ? null : _prefs.getInt(AppConstants.prefOverdueCrossedTaskId),
      overdueCrossedTaskName: _prefs.getString(AppConstants.prefOverdueCrossedTaskName),
      overduePromptShown: Set<int>.from(_prefs.getStringList(AppConstants.prefOverduePromptShown)?.map(int.parse) ?? []),
      overdueContinued: Set<int>.from(_prefs.getStringList(AppConstants.prefOverdueContinued)?.map(int.parse) ?? []),
      focusedTimeCache: focusedTimeCache,
      suppressNextActivation: _prefs.getBool(AppConstants.prefSuppressNextActivation) ?? false,
      cycleOverflowBlocked: _prefs.getBool(AppConstants.prefCycleOverflowBlocked) ?? false,
      isPermanentlyOverdue: _prefs.getBool(AppConstants.prefIsPermanentlyOverdue) ?? false,
      backgroundStartTime: _prefs.getInt(AppConstants.prefBackgroundStartTime),
      pausedTimeTotal: _prefs.getInt(AppConstants.prefPausedTimeTotal) ?? 0,
      wasInBackground: _prefs.getBool(AppConstants.prefWasInBackground) ?? false,
    );
    debugLog('TimerPersistenceManager', 'TimerState loaded: $loaded');
    return loaded;
  }

  Future<void> clearTimerState() async {
    final List<String> keys = [
      AppConstants.prefActiveTaskId,
      AppConstants.prefActiveTaskText,
      AppConstants.prefTimeRemaining,
      AppConstants.prefIsRunning,
      AppConstants.prefIsTimerActive,
      AppConstants.prefCurrentMode,
      AppConstants.prefPlannedDurationSeconds,
      AppConstants.prefFocusDurationSeconds,
      AppConstants.prefBreakDurationSeconds,
      AppConstants.prefCurrentCycle,
      AppConstants.prefTotalCycles,
      AppConstants.prefCompletedSessions,
      AppConstants.prefIsProgressBarFull,
      AppConstants.prefAllSessionsComplete,
      AppConstants.prefOverdueSessionsComplete,
      AppConstants.prefOverdueCrossedTaskId,
      AppConstants.prefOverdueCrossedTaskName,
      AppConstants.prefOverduePromptShown,
      AppConstants.prefOverdueContinued,
      AppConstants.prefFocusedTimeCache,
      AppConstants.prefSuppressNextActivation,
      AppConstants.prefCycleOverflowBlocked,
      AppConstants.prefIsPermanentlyOverdue,
      AppConstants.prefBackgroundStartTime,
      AppConstants.prefPausedTimeTotal,
      AppConstants.prefWasInBackground,
      AppConstants.prefSessionScheduled,
      AppConstants.prefApiBaseUrl,
      AppConstants.prefIsDebugMode,
    ];
    for (final k in keys) {
      await _prefs.remove(k);
    }
    debugLog('TimerPersistenceManager', 'TimerState cleared from preferences.');
  }

  Future<void> setSessionScheduled(bool scheduled) async {
    await _prefs.setBool(AppConstants.prefSessionScheduled, scheduled);
  }

  bool isSessionScheduled() => _prefs.getBool(AppConstants.prefSessionScheduled) ?? false;

  Future<void> saveApiConfig(String baseUrl, bool isDebug) async {
    await _prefs.setString(AppConstants.prefApiBaseUrl, baseUrl);
    await _prefs.setBool(AppConstants.prefIsDebugMode, isDebug);
  }

  (String, bool)? loadApiConfig() {
    final String? baseUrl = _prefs.getString(AppConstants.prefApiBaseUrl);
    final bool? isDebug = _prefs.getBool(AppConstants.prefIsDebugMode);
    if (baseUrl != null && isDebug != null) return (baseUrl, isDebug);
    return null;
  }
}
