import 'package:flutter/foundation.dart';
import 'dart:async';

class TimerService extends ChangeNotifier {
  TimerService._();
  static final TimerService instance = TimerService._();

  String? activeTaskName;
  int timeRemaining = 0; // seconds
  bool isRunning = false;
  bool isTimerActive = false; // whether mini-bar should show
  String currentMode = 'focus';
  int? plannedDurationSeconds;
  // Session (focus/break) durations so mini-bar ticker can handle transitions
  int? focusDurationSeconds;
  int? breakDurationSeconds;
  int currentCycle = 1;
  int totalCycles = 1;
  // Name of a task that just crossed its planned duration and requires prompting
  String? overdueCrossedTaskName;
  // Track which tasks have already had the overdue prompt shown so we don't spam the user
  final Set<String> _overduePromptShown = {};
  // Track tasks for which the user chose to continue working when overdue
  final Set<String> _overdueContinued = {};
  Timer? _ticker;
  // cache of latest focused time per task (seconds) for UI sync
  final Map<String, int> _focusedTimeCache = {};

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
        'TIMER SERVICE: update() called with -> taskName:$taskName remaining:$remaining running:$running active:$active mode:$mode planned:$plannedDuration',
      );
      debugPrint(
        'TIMER SERVICE: before -> activeTaskName:$activeTaskName timeRemaining:$timeRemaining isRunning:$isRunning isTimerActive:$isTimerActive currentMode:$currentMode',
      );
    }
    var changed = false;
    if (taskName != null && taskName != activeTaskName) {
      activeTaskName = taskName;
      changed = true;
    }
    if (remaining != null && remaining != timeRemaining) {
      timeRemaining = remaining;
      changed = true;
    }
    // Only update running state if explicitly set (not during view transitions)
    if (running != null && running != isRunning) {
      isRunning = running;
      changed = true;
    }
    if (active != null && active != isTimerActive) {
      isTimerActive = active;
      // Do not affect the running state when just toggling active state
      changed = true;
    }
    if (mode != null && mode != currentMode) {
      currentMode = mode;
      changed = true;
    }
    if (plannedDuration != null && plannedDuration != plannedDurationSeconds) {
      plannedDurationSeconds = plannedDuration;
      changed = true;
    }
    if (focusDuration != null && focusDuration != focusDurationSeconds) {
      focusDurationSeconds = focusDuration;
      changed = true;
    }
    if (breakDuration != null && breakDuration != breakDurationSeconds) {
      breakDurationSeconds = breakDuration;
      changed = true;
    }
    if (setTotalCycles != null && setTotalCycles != totalCycles) {
      totalCycles = setTotalCycles;
      changed = true;
    }
    if (setCurrentCycle != null && setCurrentCycle != currentCycle) {
      currentCycle = setCurrentCycle;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
    if (changed && kDebugMode) {
      debugPrint(
        'TIMER SERVICE: state changed -> activeTaskName:$activeTaskName timeRemaining:$timeRemaining isRunning:$isRunning isTimerActive:$isTimerActive currentMode:$currentMode',
      );
    }
    // Only manage ticker when running state explicitly changes
    if (running != null) {
      _manageTicker();
    }
  }

  bool hasOverduePromptBeenShown(String taskName) {
    return _overduePromptShown.contains(taskName);
  }

  void markOverduePromptShown(String taskName) {
    if (taskName.isEmpty) return;
    _overduePromptShown.add(taskName);
    // clear the crossed marker if it matches
    if (overdueCrossedTaskName == taskName) overdueCrossedTaskName = null;
    notifyListeners();
  }

  bool hasUserContinuedOverdue(String taskName) {
    return _overdueContinued.contains(taskName);
  }

  void markUserContinuedOverdue(String taskName) {
    if (taskName.isEmpty) return;
    _overdueContinued.add(taskName);
    // also mark prompt shown so we won't show it again
    _overduePromptShown.add(taskName);
    notifyListeners();
  }

  void toggleRunning() {
    isRunning = !isRunning;
    if (kDebugMode) {
      debugPrint('TIMER SERVICE: toggleRunning -> isRunning=$isRunning');
    }
    notifyListeners();
    _manageTicker();
  }

  void _manageTicker() {
    // If the mini-bar should be active and running, start a local ticker.
    if (isTimerActive && isRunning) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (_ticker != null && kDebugMode) {
          // This debug print confirms the ticker is running
          debugPrint('TIMER SERVICE: starting internal ticker (mini-bar mode)');
        }
        if (timeRemaining > 0) {
          timeRemaining -= 1;
          // Also increment focused time if in focus mode
          if (currentMode == 'focus' && activeTaskName != null) {
            final taskName = activeTaskName!;
            final currentFocus = _focusedTimeCache[taskName] ?? 0;
            _focusedTimeCache[taskName] = currentFocus + 1;
            final totalFocusedTime = _focusedTimeCache[taskName] ?? 0;

            // Check for overdue condition while running in mini-bar
            if (plannedDurationSeconds != null &&
                plannedDurationSeconds! > 0 &&
                totalFocusedTime >= plannedDurationSeconds!) {
              if (kDebugMode) {
                debugPrint(
                  'TIMER SERVICE: Task crossed planned duration -> clearing service immediately to prevent auto-transition',
                );
              }
              // Clear the service immediately to prevent auto-transition to break
              clear();
              return;
            }
            if (kDebugMode) {
              debugPrint(
                'TIMER SERVICE: internal tick -> timeRemaining=$timeRemaining, focused=${_focusedTimeCache[taskName]}',
              );
            }
          } else if (kDebugMode) {
            debugPrint(
              'TIMER SERVICE: internal tick -> timeRemaining=$timeRemaining',
            );
          }
          notifyListeners();
        } else {
          // timeRemaining == 0
          // Handle automatic transition between focus and break modes
          if (currentMode == 'focus' && breakDurationSeconds != null) {
            // Transition to break
            currentMode = 'break';
            timeRemaining = breakDurationSeconds!;
            currentCycle +=
                1; // increment cycle after a focus session completes
            if (kDebugMode) {
              debugPrint(
                'TIMER SERVICE: focus session complete -> switching to BREAK (cycle=$currentCycle/$totalCycles)',
              );
            }
            notifyListeners();
            return; // next tick will count down break
          } else if (currentMode == 'break' && focusDurationSeconds != null) {
            // Transition back to focus
            currentMode = 'focus';
            timeRemaining = focusDurationSeconds!;
            if (kDebugMode) {
              debugPrint(
                'TIMER SERVICE: break complete -> switching to FOCUS (cycle=$currentCycle/$totalCycles)',
              );
            }
            notifyListeners();
            return;
          } else {
            if (kDebugMode) {
              debugPrint(
                'TIMER SERVICE: no durations to transition, clearing.',
              );
            }
            clear();
          }
        }
      });
    } else {
      if (_ticker != null && kDebugMode) {
        debugPrint(
          'TIMER SERVICE: stopping internal ticker (mini-bar inactive or paused)',
        );
      }
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void clear() {
    if (kDebugMode) {
      debugPrint(
        'TIMER SERVICE: clear() called - resetting central timer state',
      );
    }
    activeTaskName = null;
    timeRemaining = 0;
    isRunning = false;
    isTimerActive = false;
    currentMode = 'focus';
    plannedDurationSeconds = null;
    notifyListeners();
  }

  // Focused time cache helpers - used to sync progress across UI without
  // requiring immediate backend refresh.
  void setFocusedTime(String taskName, int seconds) {
    if (taskName.isEmpty) return;
    final prev = _focusedTimeCache[taskName];
    _focusedTimeCache[taskName] = seconds;
    if (kDebugMode) {
      debugPrint(
        'TIMER SERVICE: setFocusedTime -> $taskName : $prev -> $seconds',
      );
    }
    notifyListeners();
  }

  int? getFocusedTime(String taskName) {
    final v = _focusedTimeCache[taskName];
    if (kDebugMode) {
      debugPrint('TIMER SERVICE: getFocusedTime($taskName) -> $v');
    }
    return v;
  }
}
