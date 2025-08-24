import 'dart:async';

import 'package:flutter/foundation.dart';

enum PomodoroMode { focus, breakMode }

/// A lightweight Pomodoro controller. Designed to be UI-agnostic and testable.
class PomodoroController extends ChangeNotifier {
  // Public state
  int activeTaskId = -1;
  PomodoroMode mode = PomodoroMode.focus;
  bool isRunning = false;
  int timeRemaining = 0; // seconds
  int currentCycle = 1;
  int totalCycles = 4;

  // Durations (seconds)
  int focusDuration = 25 * 60;
  int breakDuration = 5 * 60;

  // Planned duration and server-known focused time (seconds)
  int plannedDurationSeconds = 0;
  int _serverKnownFocusedSeconds = 0;

  // Callbacks consumers can attach
  /// Called when a focus segment completes (or is paused) with number of seconds to add.
  void Function(int taskId, int addedSeconds)? onFocusSegmentComplete;

  /// Called when a task becomes overdue (total focused >= plannedDurationSeconds)
  void Function(int taskId)? onOverdue;

  /// Called on session transitions (focus->break, break->focus)
  void Function(PomodoroMode newMode)? onSessionTransition;

  Timer? _ticker;
  DateTime? _focusStart;
  // previously used for run-accumulation; removed to satisfy analyzer

  PomodoroController();

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  void _startTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    if (!isRunning) return;
    timeRemaining = (timeRemaining - 1).clamp(0, 24 * 3600);
    notifyListeners();
    if (timeRemaining <= 0) {
      // session ended
      if (mode == PomodoroMode.focus) {
        _handleFocusEnd(fullSession: true);
      } else {
        _handleBreakEnd();
      }
    }
  }

  /// Start or resume a Pomodoro session for a task.
  /// [initialFocusedSeconds] is the current focused_time known on server so we can detect overdue correctly.
  void start(
    int taskId, {
    int? focusSec,
    int? breakSec,
    int? cycles,
    int plannedDurationSec = 0,
    int initialFocusedSeconds = 0,
  }) {
    // If switching tasks, reset run-accumulators
    if (activeTaskId != taskId) {
      currentCycle = 1;
      mode = PomodoroMode.focus;
    }
    activeTaskId = taskId;
    focusDuration = focusSec ?? focusDuration;
    breakDuration = breakSec ?? breakDuration;
    totalCycles = cycles ?? totalCycles;
    plannedDurationSeconds = plannedDurationSec;
    _serverKnownFocusedSeconds = initialFocusedSeconds;

    if (mode == PomodoroMode.focus) {
      timeRemaining = timeRemaining > 0 ? timeRemaining : focusDuration;
      _focusStart ??= DateTime.now();
    } else {
      timeRemaining = timeRemaining > 0 ? timeRemaining : breakDuration;
    }

    isRunning = true;
    _startTicker();
    notifyListeners();
  }

  /// Pause the timer and flush any partial focus seconds
  Future<void> pause() async {
    if (!isRunning) return;
    isRunning = false;
    _stopTicker();
    // If we were in focus mode, compute elapsed since _focusStart
    if (mode == PomodoroMode.focus && _focusStart != null) {
      final elapsed = DateTime.now().difference(_focusStart!).inSeconds;
      final added = elapsed.clamp(0, focusDuration - (timeRemaining));
      if (added > 0) {
        _serverKnownFocusedSeconds += added;
        onFocusSegmentComplete?.call(activeTaskId, added);
        // Overdue detection
        if (plannedDurationSeconds > 0 &&
            _serverKnownFocusedSeconds >= plannedDurationSeconds) {
          onOverdue?.call(activeTaskId);
        }
      }
    }
    _focusStart = null;
    notifyListeners();
  }

  void _handleFocusEnd({bool fullSession = false}) {
    // compute added seconds: if fullSession true we add the remaining focusDuration,
    // else compute from _focusStart
    int added = 0;
    if (fullSession) {
      added = focusDuration - (timeRemaining < 0 ? 0 : 0);
      // safer: assume full focusDuration elapsed
      added = focusDuration;
    } else if (_focusStart != null) {
      added = DateTime.now().difference(_focusStart!).inSeconds;
    }
    added = added.clamp(0, focusDuration);
    _serverKnownFocusedSeconds += added;
    onFocusSegmentComplete?.call(activeTaskId, added);

    // Check overdue
    if (plannedDurationSeconds > 0 &&
        _serverKnownFocusedSeconds >= plannedDurationSeconds) {
      onOverdue?.call(activeTaskId);
    }

    // move to break
    mode = PomodoroMode.breakMode;
    timeRemaining = breakDuration;
    _focusStart = null;
    notifyListeners();
    onSessionTransition?.call(mode);
  }

  void _handleBreakEnd() {
    // finished a break, move to next cycle
    currentCycle = (currentCycle + 1).clamp(1, totalCycles);
    mode = PomodoroMode.focus;
    timeRemaining = focusDuration;
    _focusStart = DateTime.now();
    notifyListeners();
    onSessionTransition?.call(mode);
    // If we've reached total cycles, stop
    if (currentCycle > totalCycles) {
      // finalize
      isRunning = false;
      _stopTicker();
      notifyListeners();
    }
  }

  /// Skip the current session and start the next
  Future<void> skip() async {
    if (mode == PomodoroMode.focus) {
      // flush partial focus seconds (computed by elapsed)
      if (_focusStart != null) {
        final elapsed = DateTime.now().difference(_focusStart!).inSeconds;
        final added = elapsed.clamp(0, focusDuration - (timeRemaining));
        if (added > 0) {
          _serverKnownFocusedSeconds += added;
          onFocusSegmentComplete?.call(activeTaskId, added);
          if (plannedDurationSeconds > 0 &&
              _serverKnownFocusedSeconds >= plannedDurationSeconds) {
            onOverdue?.call(activeTaskId);
          }
        }
      }
      // switch to break
      mode = PomodoroMode.breakMode;
      timeRemaining = breakDuration;
      _focusStart = null;
      // Auto-start next session
      isRunning = true;
      _startTicker();
      notifyListeners();
      onSessionTransition?.call(mode);
    } else {
      // skip break -> focus
      mode = PomodoroMode.focus;
      timeRemaining = focusDuration;
      _focusStart = DateTime.now();
      // Auto-start next session
      isRunning = true;
      _startTicker();
      notifyListeners();
      onSessionTransition?.call(mode);
    }
  }

  /// Reset the current run: stop timer and set timeRemaining back to focus duration.
  /// Returns the number of seconds that were part of the partial focus (if any) — caller may subtract this from server value.
  int reset() {
    int partial = 0;
    if (mode == PomodoroMode.focus && _focusStart != null) {
      partial = DateTime.now().difference(_focusStart!).inSeconds;
      partial = partial.clamp(0, focusDuration);
    }
    isRunning = false;
    _stopTicker();
    mode = PomodoroMode.focus;
    timeRemaining = focusDuration;
    _focusStart = null;
    // reset any partial-run accumulation (no-op without accumulator)
    notifyListeners();
    return partial;
  }
}
