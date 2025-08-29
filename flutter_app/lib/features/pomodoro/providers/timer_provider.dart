import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/timer_session_controller.dart';
import '../../../core/providers/notification_provider.dart';
import '../../todo/providers/todos_provider.dart';

class TimerState {
  final String? activeTaskName;
  final int timeRemaining; // seconds
  final bool isRunning;
  final bool isTimerActive; // whether mini-bar should show
  final String currentMode;
  final int? plannedDurationSeconds;
  final int? focusDurationSeconds;
  final int? breakDurationSeconds;
  final int currentCycle;
  final int totalCycles;
  // Session tracking
  final int completedSessions;
  final bool isProgressBarFull;
  final bool allSessionsComplete;
  final String? overdueCrossedTaskName;
  final Set<String> overduePromptShown;
  final Set<String> overdueContinued;
  final Map<String, int> focusedTimeCache;
  final bool suppressNextActivation;
  final bool cycleOverflowBlocked;

  const TimerState({
    this.activeTaskName,
    this.timeRemaining = 0,
    this.isRunning = false,
    this.isTimerActive = false,
    this.currentMode = 'focus',
    this.plannedDurationSeconds,
    this.focusDurationSeconds,
    this.breakDurationSeconds,
    this.currentCycle = 1,
    this.totalCycles = 1,
    this.completedSessions = 0,
    this.isProgressBarFull = false,
    this.allSessionsComplete = false,
    this.overdueCrossedTaskName,
    this.overduePromptShown = const {},
    this.overdueContinued = const {},
    this.focusedTimeCache = const {},
    this.suppressNextActivation = false,
    this.cycleOverflowBlocked = false,
  });

  TimerState copyWith({
    String? activeTaskName,
    int? timeRemaining,
    bool? isRunning,
    bool? isTimerActive,
    String? currentMode,
    int? plannedDurationSeconds,
    int? focusDurationSeconds,
    int? breakDurationSeconds,
    int? currentCycle,
    int? totalCycles,
    int? completedSessions,
    bool? isProgressBarFull,
    bool? allSessionsComplete,
    String? overdueCrossedTaskName,
    Set<String>? overduePromptShown,
    Set<String>? overdueContinued,
    Map<String, int>? focusedTimeCache,
    bool? suppressNextActivation,
    bool? cycleOverflowBlocked,
  }) {
    return TimerState(
      activeTaskName: activeTaskName ?? this.activeTaskName,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      isRunning: isRunning ?? this.isRunning,
      isTimerActive: isTimerActive ?? this.isTimerActive,
      currentMode: currentMode ?? this.currentMode,
      plannedDurationSeconds:
          plannedDurationSeconds ?? this.plannedDurationSeconds,
      focusDurationSeconds: focusDurationSeconds ?? this.focusDurationSeconds,
      breakDurationSeconds: breakDurationSeconds ?? this.breakDurationSeconds,
      currentCycle: currentCycle ?? this.currentCycle,
      totalCycles: totalCycles ?? this.totalCycles,
      completedSessions: completedSessions ?? this.completedSessions,
      isProgressBarFull: isProgressBarFull ?? this.isProgressBarFull,
      allSessionsComplete: allSessionsComplete ?? this.allSessionsComplete,
      overdueCrossedTaskName:
          overdueCrossedTaskName ?? this.overdueCrossedTaskName,
      overduePromptShown: overduePromptShown ?? this.overduePromptShown,
      overdueContinued: overdueContinued ?? this.overdueContinued,
      focusedTimeCache: focusedTimeCache ?? this.focusedTimeCache,
      suppressNextActivation:
          suppressNextActivation ?? this.suppressNextActivation,
      cycleOverflowBlocked: cycleOverflowBlocked ?? this.cycleOverflowBlocked,
    );
  }
}

/// Core timer state management provider for the Pomodoro application.
///
/// Manages timer lifecycle, state transitions, sound/notification integration,
/// progress tracking, and API synchronization. Provides smart business logic
/// for automatic cycle progression and overdue handling.
class TimerNotifier extends Notifier<TimerState> {
  Timer? _ticker;
  // Autosave infrastructure (durability of focused time against crashes)
  Timer? _autoSaveTimer;
  bool _isAutoSaving = false;
  int _lastAutoSavedSeconds = 0;
  bool _processingOverdue = false;
  TimerSessionController? _sessionController;
  DateTime? _lastStartAttempt;

  @override
  TimerState build() {
    // Only create session controller once
    _sessionController ??= TimerSessionController();
    ref.onDispose(() {
      _ticker?.cancel();
    });
    return const TimerState();
  }

  /// Updates timer state with provided parameters.
  ///
  /// Only updates fields that have changed to minimize unnecessary rebuilds.
  /// Logs state changes in debug mode for development tracking.
  ///
  /// Parameters:
  /// - [taskName]: Name of the active task
  /// - [remaining]: Time remaining in seconds
  /// - [running]: Whether timer is currently running
  /// - [active]: Whether timer session is active
  /// - [plannedDuration]: Planned duration for the task in seconds
  /// - [mode]: Current timer mode ('focus' or 'break')
  /// - [focusDuration]: Duration of focus periods in seconds
  /// - [breakDuration]: Duration of break periods in seconds
  /// - [setTotalCycles]: Total number of focus/break cycles
  /// - [setCurrentCycle]: Current cycle number
  void update({
    String? taskName,
    int? remaining,
    bool? running,
    bool? active,
    int? plannedDuration,
    String? mode,
    int? focusDuration,
    int? breakDuration,
    int? setTotalCycles,
    int? setCurrentCycle,
  }) {
    if (kDebugMode) {
      debugPrint(
        'TIMER PROVIDER: update() called with -> taskName:$taskName remaining:$remaining running:$running active:$active mode:$mode planned:$plannedDuration',
      );
      debugPrint(
        'TIMER PROVIDER: before -> activeTaskName:${state.activeTaskName} timeRemaining:${state.timeRemaining} isRunning:${state.isRunning} isTimerActive:${state.isTimerActive} currentMode:${state.currentMode}',
      );
    }
    var changed = false;
    var newState = state;

    if (taskName != null && taskName != state.activeTaskName) {
      newState = newState.copyWith(activeTaskName: taskName);
      changed = true;
    }
    if (remaining != null && remaining != state.timeRemaining) {
      newState = newState.copyWith(timeRemaining: remaining);
      changed = true;
    }
    if (running != null && running != state.isRunning) {
      newState = newState.copyWith(isRunning: running);
      changed = true;
    }
    if (active != null && active != state.isTimerActive) {
      newState = newState.copyWith(isTimerActive: active);
      changed = true;
    }
    if (mode != null && mode != state.currentMode) {
      newState = newState.copyWith(currentMode: mode);
      changed = true;
    }
    if (plannedDuration != null &&
        plannedDuration != state.plannedDurationSeconds) {
      newState = newState.copyWith(plannedDurationSeconds: plannedDuration);
      changed = true;
    }
    if (focusDuration != null && focusDuration != state.focusDurationSeconds) {
      newState = newState.copyWith(focusDurationSeconds: focusDuration);
      changed = true;
    }
    if (breakDuration != null && breakDuration != state.breakDurationSeconds) {
      newState = newState.copyWith(breakDurationSeconds: breakDuration);
      changed = true;
    }
    if (setTotalCycles != null && setTotalCycles != state.totalCycles) {
      newState = newState.copyWith(totalCycles: setTotalCycles);
      changed = true;
    }
    if (setCurrentCycle != null && setCurrentCycle != state.currentCycle) {
      newState = newState.copyWith(currentCycle: setCurrentCycle);
      changed = true;
    }

    if (changed) {
      state = newState;
      if (kDebugMode) {
        debugPrint(
          'TIMER PROVIDER: after -> activeTaskName:${state.activeTaskName} timeRemaining:${state.timeRemaining} isRunning:${state.isRunning} isTimerActive:${state.isTimerActive} currentMode:${state.currentMode}',
        );
      }
    }
  }

  /// Marks that an overdue prompt has been shown for a specific task.
  ///
  /// Prevents duplicate overdue prompts for the same task during a session.
  ///
  /// Parameters:
  /// - [taskName]: Name of the task that triggered the overdue prompt
  void markOverduePromptShown(String taskName) {
    final newPromptShown = Set<String>.from(state.overduePromptShown)
      ..add(taskName);
    state = state.copyWith(overduePromptShown: newPromptShown);
  }

  /// Marks that a user chose to continue working on an overdue task.
  ///
  /// Tracks which tasks have been continued past their planned duration
  /// for analytics and UI state management.
  ///
  /// Parameters:
  /// - [taskName]: Name of the task that was continued past its planned time
  void markOverdueContinued(String taskName) {
    final newOverdueContinued = Set<String>.from(state.overdueContinued)
      ..add(taskName);
    state = state.copyWith(overdueContinued: newOverdueContinued);
  }

  /// Updates the total focused time for a specific task.
  ///
  /// Maintains a cache of focused time per task for progress tracking
  /// and progress bar calculations.
  ///
  /// Parameters:
  /// - [taskName]: Name of the task to update
  /// - [seconds]: Total focused time in seconds
  void updateFocusedTime(String taskName, int seconds) {
    final newFocusedTimeCache = Map<String, int>.from(state.focusedTimeCache);
    newFocusedTimeCache[taskName] = seconds;
    state = state.copyWith(focusedTimeCache: newFocusedTimeCache);
  }

  /// Gets the total focused time for a specific task.
  ///
  /// Returns the cumulative focused time from the cache or 0 if no
  /// time has been tracked for the task.
  ///
  /// Parameters:
  /// - [taskName]: Name of the task to query
  ///
  /// Returns: Total focused time in seconds
  int getFocusedTime(String taskName) {
    return state.focusedTimeCache[taskName] ?? 0;
  }

  void setOverdueCrossed(String? taskName) {
    state = state.copyWith(overdueCrossedTaskName: taskName);
  }

  void setSuppressNextActivation(bool suppress) {
    state = state.copyWith(suppressNextActivation: suppress);
  }

  void startTicker() {
    _ticker?.cancel();
    _startAutoSaveTimer();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isRunning) return;
      if (state.timeRemaining > 0) {
        // Decrement and increment focused time cache if in focus mode.
        var newFocusedTimeCache = state.focusedTimeCache;
        if (state.currentMode == 'focus' && state.activeTaskName != null) {
          final task = state.activeTaskName!;
          final current = newFocusedTimeCache[task] ?? 0;
          newFocusedTimeCache = Map<String, int>.from(newFocusedTimeCache)
            ..[task] = current + 1;
        }
        state = state.copyWith(
          timeRemaining: state.timeRemaining - 1,
          focusedTimeCache: newFocusedTimeCache,
        );
      } else {
        // Handle transitions similar to legacy service (simplified for bridge).
        if (state.currentMode == 'focus' &&
            state.breakDurationSeconds != null) {
          // *** SMART BUSINESS LOGIC: Play break sound and show notification ***
          try {
            final notificationService = ref.read(notificationServiceProvider);
            notificationService.playSound('break_timer_start.wav');
            notificationService.showNotification(
              title: 'Focus Session Complete!',
              body: 'Time for a break. Great work!',
            );
          } catch (e) {
            if (kDebugMode) debugPrint('SOUND/NOTIFICATION ERROR: $e');
          }

          // Mark completion of a focus session
          final completed = state.completedSessions + 1;
          state = state.copyWith(completedSessions: completed);
          // If all sessions complete trigger freeze (UI can observe)
          if (completed >= state.totalCycles && !state.isProgressBarFull) {
            state = state.copyWith(allSessionsComplete: true);
          }
          // Increment cycle but cap at totalCycles (no 3/2 situations)
          final nextCycle = (state.currentCycle + 1) <= state.totalCycles
              ? state.currentCycle + 1
              : state.totalCycles;
          state = state.copyWith(
            currentMode: 'break',
            timeRemaining: state.breakDurationSeconds,
            currentCycle: nextCycle,
          );
        } else if (state.currentMode == 'break' &&
            state.focusDurationSeconds != null) {
          // *** SMART BUSINESS LOGIC: Play focus sound and show notification ***
          try {
            final notificationService = ref.read(notificationServiceProvider);
            notificationService.playSound('focus_timer_start.wav');
            notificationService.showNotification(
              title: 'Break Complete!',
              body: 'Time to focus. Let\'s get back to work!',
            );
          } catch (e) {
            if (kDebugMode) debugPrint('SOUND/NOTIFICATION ERROR: $e');
          }

          state = state.copyWith(
            currentMode: 'focus',
            timeRemaining: state.focusDurationSeconds,
          );
        } else {
          // No transition data -> stop
          stop();
        }
      }

      // Overdue detection when focus time meets or exceeds planned.
      if (!_processingOverdue &&
          state.currentMode == 'focus' &&
          state.activeTaskName != null &&
          state.plannedDurationSeconds != null) {
        final focused = state.focusedTimeCache[state.activeTaskName!] ?? 0;
        if (focused >= state.plannedDurationSeconds! &&
            state.overdueCrossedTaskName != state.activeTaskName) {
          _processingOverdue = true;
          _markOverdueAndFreeze(state.activeTaskName!);
          _processingOverdue = false;
        }
      }
    });
  }

  void stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  void _markOverdueAndFreeze(String task) {
    // Use FSM to handle overdue transition
    final success =
        _sessionController?.handleEvent(TimerSessionEvent.overdueReached) ??
        false;
    if (success && kDebugMode) {
      debugPrint('TIMER_FSM: Task $task reached overdue state');
    }

    // Freeze timer but keep mini-bar visible for one frame so UI can prompt.
    _ticker?.cancel();
    _ticker = null;
    state = state.copyWith(
      isRunning: false,
      timeRemaining: 0,
      isProgressBarFull: true, // Add this flag to signal the UI
      overdueCrossedTaskName: task,
      // Preserve activeTaskName & isTimerActive
      // Clear adjustable durations
      plannedDurationSeconds: null,
      focusDurationSeconds: null,
      breakDurationSeconds: null,
      currentCycle: 1,
      totalCycles: 1,
    );
  }

  /// Trigger overdue dialog from UI
  Future<String?> triggerOverdueDialog() async {
    final taskName = state.overdueCrossedTaskName;
    if (taskName == null) return null;

    final focusedTime = getFocusedTime(taskName);
    final plannedTime = state.plannedDurationSeconds ?? 0;

    if (kDebugMode) {
      debugPrint('TIMER_FSM: Triggering overdue dialog for $taskName');
      debugPrint(
        'TIMER_FSM: Focused: ${focusedTime}s, Planned: ${plannedTime}s',
      );
    }

    return taskName; // Return task name to trigger dialog in UI
  }

  void logStateSnapshot(String prefix) {
    if (kDebugMode) {
      debugPrint('$prefix: TimerState(');
      debugPrint('  activeTaskName: ${state.activeTaskName}');
      debugPrint('  timeRemaining: ${state.timeRemaining}');
      debugPrint('  isRunning: ${state.isRunning}');
      debugPrint('  isTimerActive: ${state.isTimerActive}');
      debugPrint('  currentMode: ${state.currentMode}');
      debugPrint('  plannedDurationSeconds: ${state.plannedDurationSeconds}');
      debugPrint('  currentCycle: ${state.currentCycle}');
      debugPrint('  totalCycles: ${state.totalCycles}');
      debugPrint(')');
    }
  }

  void deactivate() {
    update(active: false);
  }

  void stop() {
    update(running: false);
    stopTicker();
  }

  void reset() {
    stopTicker();
    // Force reset the session controller instead of just sending abort event
    _sessionController?.forceReset();
    state = const TimerState();
  }

  // UX Flow: Reset current phase only and subtract elapsed time from focused time cache
  void resetCurrentPhase() {
    if (state.activeTaskName == null) return;

    if (kDebugMode) {
      debugPrint('RESET: Resetting current phase for ${state.activeTaskName}');
    }

    // Calculate elapsed time in current phase
    final currentPhaseDuration = state.currentMode == 'focus'
        ? (state.focusDurationSeconds ?? 25 * 60)
        : (state.breakDurationSeconds ?? 5 * 60);
    final elapsedTime = currentPhaseDuration - state.timeRemaining;

    // Only subtract time if we're in focus mode and time has elapsed
    if (state.currentMode == 'focus' && elapsedTime > 0) {
      final taskName = state.activeTaskName!;
      final currentFocusedTime = getFocusedTime(taskName);
      final newFocusedTime = (currentFocusedTime - elapsedTime)
          .clamp(0, double.infinity)
          .toInt();

      if (kDebugMode) {
        debugPrint('RESET: Subtracting $elapsedTime seconds from focused time');
        debugPrint(
          'RESET: Previous focused time: $currentFocusedTime, New: $newFocusedTime',
        );
      }

      updateFocusedTime(taskName, newFocusedTime);
    }

    // Reset the current phase timer to full duration
    state = state.copyWith(
      timeRemaining: currentPhaseDuration,
      isRunning: false,
    );

    stopTicker();
  }

  void clear() {
    stopTicker();
    // Force reset the session controller instead of just sending abort event
    _sessionController?.forceReset();
    state = const TimerState();
  }

  /// Attempts an autosave of focused time before clearing state. Use when
  /// disposing due to navigation/app lifecycle to reduce data loss risk.
  Future<void> safeClear({int? todoId}) async {
    try {
      if (todoId != null && state.activeTaskName != null) {
        await _autoSaveFocusedTime(todoId: todoId, force: true);
      }
    } catch (_) {}
    clear();
  }

  /// Clear active session while preserving historical focused time cache so task progress bars remain.
  void clearPreserveProgress() {
    stopTicker();
    _sessionController?.forceReset();
    final preserved = state.focusedTimeCache;
    state = TimerState(focusedTimeCache: preserved);
  }

  /// Saves current progress and safely stops the timer session.
  ///
  /// Critical feature that ensures no progress is lost when stopping a session.
  /// Updates the backend with current focused time and gracefully clears the session.
  ///
  /// Parameters:
  /// - [todoId]: Database ID of the todo item to update
  ///
  /// Returns: true if progress was saved successfully, false if an error occurred
  Future<bool> stopAndSaveProgress(int todoId) async {
    if (state.activeTaskName == null) {
      // No active session to save
      clear();
      return true;
    }

    try {
      // Calculate elapsed time in current session
      final taskName = state.activeTaskName!;
      final currentFocusedTime = state.focusedTimeCache[taskName] ?? 0;

      if (kDebugMode) {
        debugPrint(
          'TIMER: Saving progress for $taskName (ID: $todoId): ${currentFocusedTime}s focused time',
        );
      }

      // Update backend with current focused time
      final api = ref.read(apiServiceProvider);
      await api.updateFocusTime(todoId, currentFocusedTime);

      // Clear the session but preserve progress cache
      clearPreserveProgress();

      if (kDebugMode) {
        debugPrint('TIMER: Progress saved successfully for $taskName');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TIMER: Failed to save progress: $e');
      }
      // Even if save fails, we should clear the session to prevent data inconsistency
      clearPreserveProgress();
      return false;
    }
  }

  void toggleRunning() {
    final nextRunning = !state.isRunning;
    state = state.copyWith(isRunning: nextRunning);
    if (nextRunning) {
      startTicker();
    } else {
      stopTicker();
    }
  }

  /// Starts a new Pomodoro timer session with smart business logic.
  ///
  /// Initializes a new timer session with the specified parameters, plays
  /// notification sounds, and starts the focus timer. Includes debouncing
  /// to prevent rapid start attempts.
  ///
  /// Parameters:
  /// - [taskName]: Name of the task to focus on
  /// - [focusDuration]: Duration of focus periods in seconds
  /// - [breakDuration]: Duration of break periods in seconds
  /// - [plannedDuration]: Planned total duration for the task in seconds
  /// - [totalCycles]: Total number of focus/break cycles to complete
  ///
  /// Returns: true if session started successfully, false if start was prevented
  bool startTask({
    required String taskName,
    required int focusDuration,
    required int breakDuration,
    required int plannedDuration,
    required int totalCycles,
  }) {
    // Debounce rapid start attempts (prevent multiple calls within 500ms)
    final now = DateTime.now();
    if (_lastStartAttempt != null &&
        now.difference(_lastStartAttempt!).inMilliseconds < 500) {
      if (kDebugMode) {
        debugPrint('TIMER_FSM: Debouncing rapid start attempt for $taskName');
      }
      return false;
    }
    _lastStartAttempt = now;

    // Force reset if session controller is stuck
    if (_sessionController?.currentState != TimerSessionState.idle) {
      if (kDebugMode) {
        debugPrint('TIMER_FSM: Force resetting stuck session controller');
      }
      _sessionController?.forceReset();
    }

    // Start FSM session
    final success =
        _sessionController?.startSession(
          taskName: taskName,
          focusDurationSeconds: focusDuration,
          breakDurationSeconds: breakDuration,
          totalCycles: totalCycles,
        ) ??
        false;

    if (!success) {
      if (kDebugMode) {
        debugPrint('TIMER_FSM: Failed to start session for $taskName');
      }
      return false;
    }

    // *** SMART BUSINESS LOGIC: Play focus start sound and show notification ***
    try {
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.playSound('focus_timer_start.wav');
      notificationService.showNotification(
        title: 'Focus Session Started!',
        body: 'Focus time for "$taskName". You\'ve got this!',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('SOUND/NOTIFICATION ERROR: $e');
    }

    state = state.copyWith(
      activeTaskName: taskName,
      focusDurationSeconds: focusDuration,
      breakDurationSeconds: breakDuration,
      plannedDurationSeconds: plannedDuration,
      totalCycles: totalCycles,
      currentCycle: 1,
      timeRemaining: focusDuration,
      currentMode: 'focus',
      isTimerActive: false,
      isRunning: true,
    );
    startTicker();
    return true;
  }

  void pauseTask() {
    state = state.copyWith(isRunning: false);
    stopTicker();
    _triggerDeferredAutoSave();
  }

  void resumeTask() {
    if (!state.isRunning) {
      state = state.copyWith(isRunning: true);
      startTicker();
      _startAutoSaveTimer();
    }
  }

  void updateDurations({
    int? focusDuration,
    int? breakDuration,
    int? totalCycles,
  }) {
    state = state.copyWith(
      focusDurationSeconds: focusDuration ?? state.focusDurationSeconds,
      breakDurationSeconds: breakDuration ?? state.breakDurationSeconds,
      totalCycles: totalCycles ?? state.totalCycles,
      // Only realign remaining time if user is still in initial setup (cycle 0)
      timeRemaining:
          (!state.isRunning &&
              state.currentMode == 'focus' &&
              focusDuration != null &&
              state.currentCycle == 0)
          ? focusDuration
          : state.timeRemaining,
    );
  }

  void markProgressBarFull() {
    state = state.copyWith(isProgressBarFull: true);
  }

  void clearProgressBarFullFlag() {
    if (state.isProgressBarFull) {
      if (kDebugMode) {
        debugPrint('TIMER: Clearing progressBarFull flag');
      }
      state = state.copyWith(isProgressBarFull: false);
    }
  }

  void clearCycleOverflowBlockedFlag() {
    if (state.cycleOverflowBlocked) {
      state = state.copyWith(cycleOverflowBlocked: false);
    }
  }

  void resetForSetup({
    required int focusDuration,
    required int breakDuration,
    required int totalCycles,
  }) {
    stopTicker();
    state = state.copyWith(
      isRunning: false,
      currentMode: 'focus',
      timeRemaining: focusDuration,
      focusDurationSeconds: focusDuration,
      breakDurationSeconds: breakDuration,
      totalCycles: totalCycles,
      currentCycle: 0,
      completedSessions: 0,
      isProgressBarFull: false,
      allSessionsComplete: false,
    );
  }

  void resetForSetupWithTask({
    required String taskName,
    required int focusDuration,
    required int breakDuration,
    required int totalCycles,
    required int plannedDuration,
  }) {
    stopTicker();
    // Preserve focusedTimeCache so progress bars retain prior accumulated time when revisiting a task
    final cache = state.focusedTimeCache;
    state = state.copyWith(
      activeTaskName: taskName,
      focusDurationSeconds: focusDuration,
      breakDurationSeconds: breakDuration,
      totalCycles: totalCycles,
      plannedDurationSeconds: plannedDuration,
      timeRemaining: focusDuration,
      currentMode: 'focus',
      isRunning: false,
      currentCycle: 0,
      completedSessions: 0,
      isProgressBarFull: false,
      allSessionsComplete: false,
      focusedTimeCache: cache, // re-apply preserved cache
      // *** FIX: Clear overdue-related flags when starting a new session ***
      overdueCrossedTaskName: null,
      isTimerActive: false,
    );
    _lastAutoSavedSeconds = state.focusedTimeCache[taskName] ?? 0;
  }

  // ---------------- AUTOSAVE IMPLEMENTATION ----------------
  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _triggerDeferredAutoSave();
    });
  }

  void _triggerDeferredAutoSave() {
    final taskName = state.activeTaskName;
    if (taskName == null) return;
    final currentFocused = state.focusedTimeCache[taskName] ?? 0;
    if (currentFocused - _lastAutoSavedSeconds < 30) return; // threshold
    final todos = ref.read(todosProvider).value;
    final match = todos?.firstWhere(
      (t) => t.text == taskName,
      orElse: () => null as dynamic,
    );
    if (match != null) {
      _autoSaveFocusedTime(todoId: match.id);
    }
  }

  Future<void> _autoSaveFocusedTime({
    required int todoId,
    bool force = false,
  }) async {
    final taskName = state.activeTaskName;
    if (taskName == null) return;
    final currentFocused = state.focusedTimeCache[taskName] ?? 0;
    if (!force && currentFocused <= _lastAutoSavedSeconds) return;
    if (_isAutoSaving) return;
    _isAutoSaving = true;
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateFocusTime(todoId, currentFocused);
      _lastAutoSavedSeconds = currentFocused;
      if (kDebugMode) {
        debugPrint(
          'AUTOSAVE: Saved $currentFocused for "$taskName" (todoId=$todoId)',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AUTOSAVE ERROR: $e');
    } finally {
      _isAutoSaving = false;
    }
  }

  void skipPhase() {
    if (state.currentMode == 'focus') {
      // Prevent going beyond total cycles
      if (state.currentCycle >= state.totalCycles) {
        state = state.copyWith(cycleOverflowBlocked: true);
        return;
      }
      final completed = state.completedSessions + 1;
      final nextCycle = state.currentCycle + 1;
      state = state.copyWith(
        currentMode: 'break',
        timeRemaining: state.breakDurationSeconds ?? state.timeRemaining,
        completedSessions: completed,
        currentCycle: nextCycle,
      );
    } else if (state.currentMode == 'break') {
      state = state.copyWith(
        currentMode: 'focus',
        timeRemaining: state.focusDurationSeconds ?? state.timeRemaining,
      );
    }
  }

  bool hasOverduePromptBeenShown(String task) =>
      state.overduePromptShown.contains(task);
  bool hasUserContinuedOverdue(String task) =>
      state.overdueContinued.contains(task);
  void markUserContinuedOverdue(String task) => markOverdueContinued(task);

  void clearAllSessionsCompleteFlag() {
    state = state.copyWith(allSessionsComplete: false);
  }
}

// The main timer provider
final timerProvider = NotifierProvider<TimerNotifier, TimerState>(
  () => TimerNotifier(),
);

// Legacy bridge removed; TimerNotifier is now sole source of truth.
