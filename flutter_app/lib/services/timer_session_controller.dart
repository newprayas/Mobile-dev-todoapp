import 'package:flutter/foundation.dart';

/// Timer session states representing the FSM
enum TimerSessionState {
  idle, // No active session
  focusActive, // Focus session running
  focusPaused, // Focus session paused
  breakActive, // Break session running
  breakPaused, // Break session paused
  overdue, // Task has exceeded planned time
  completed, // All sessions completed
}

/// Event types for state transitions
enum TimerSessionEvent {
  start,
  pause,
  resume,
  complete,
  overdueReached,
  reset,
  abort,
}

/// Controller for managing timer session FSM
class TimerSessionController {
  TimerSessionState _currentState = TimerSessionState.idle;
  String? _activeTask;
  int _currentCycle = 1;
  int _totalCycles = 1;
  int _focusSeconds = 0;
  int _breakSeconds = 0;
  int _timeRemaining = 0;
  bool _isOverdue = false;
  final Set<String> _overduePromptShown = {};
  final Set<String> _overdueContinued = {};
  final Map<String, int> _focusedTimeCache = {};

  TimerSessionState get currentState => _currentState;
  String? get activeTask => _activeTask;
  int get currentCycle => _currentCycle;
  int get totalCycles => _totalCycles;
  int get timeRemaining => _timeRemaining;
  bool get isOverdue => _isOverdue;
  Map<String, int> get focusedTimeCache => Map.unmodifiable(_focusedTimeCache);

  /// Start a new session
  bool startSession({
    required String taskName,
    required int focusDurationSeconds,
    required int breakDurationSeconds,
    required int totalCycles,
  }) {
    if (kDebugMode) {
      debugPrint('TIMER_FSM: Starting session for task: $taskName');
    }

    if (_currentState != TimerSessionState.idle) {
      if (kDebugMode) {
        debugPrint('TIMER_FSM: Cannot start - current state: $_currentState');
      }
      return false;
    }

    _activeTask = taskName;
    _focusSeconds = focusDurationSeconds;
    _breakSeconds = breakDurationSeconds;
    _totalCycles = totalCycles;
    _currentCycle = 1;
    _timeRemaining = focusDurationSeconds;
    _isOverdue = false;

    _currentState = TimerSessionState.focusActive;

    if (kDebugMode) {
      debugPrint('TIMER_FSM: Session started - state: $_currentState');
    }
    return true;
  }

  /// Handle state transition events
  bool handleEvent(TimerSessionEvent event) {
    final previousState = _currentState;

    switch (_currentState) {
      case TimerSessionState.idle:
        // Only start event allowed from idle
        break;

      case TimerSessionState.focusActive:
        switch (event) {
          case TimerSessionEvent.pause:
            _currentState = TimerSessionState.focusPaused;
            break;
          case TimerSessionEvent.complete:
            _handleFocusComplete();
            break;
          case TimerSessionEvent.overdueReached:
            _currentState = TimerSessionState.overdue;
            _isOverdue = true;
            break;
          case TimerSessionEvent.abort:
            _resetToIdle();
            break;
          default:
            return false;
        }
        break;

      case TimerSessionState.focusPaused:
        switch (event) {
          case TimerSessionEvent.resume:
            _currentState = TimerSessionState.focusActive;
            break;
          case TimerSessionEvent.abort:
            _resetToIdle();
            break;
          default:
            return false;
        }
        break;

      case TimerSessionState.breakActive:
        switch (event) {
          case TimerSessionEvent.pause:
            _currentState = TimerSessionState.breakPaused;
            break;
          case TimerSessionEvent.complete:
            _handleBreakComplete();
            break;
          case TimerSessionEvent.abort:
            _resetToIdle();
            break;
          default:
            return false;
        }
        break;

      case TimerSessionState.breakPaused:
        switch (event) {
          case TimerSessionEvent.resume:
            _currentState = TimerSessionState.breakActive;
            break;
          case TimerSessionEvent.abort:
            _resetToIdle();
            break;
          default:
            return false;
        }
        break;

      case TimerSessionState.overdue:
        switch (event) {
          case TimerSessionEvent.reset:
            _resetToIdle();
            break;
          case TimerSessionEvent.abort:
            _resetToIdle();
            break;
          default:
            return false;
        }
        break;

      case TimerSessionState.completed:
        switch (event) {
          case TimerSessionEvent.reset:
            _resetToIdle();
            break;
          default:
            return false;
        }
        break;
    }

    if (kDebugMode && previousState != _currentState) {
      debugPrint(
        'TIMER_FSM: State transition: $previousState -> $_currentState (event: $event)',
      );
    }

    return previousState != _currentState;
  }

  /// Handle focus session completion
  void _handleFocusComplete() {
    if (_currentCycle >= _totalCycles) {
      _currentState = TimerSessionState.completed;
    } else {
      _currentCycle++;
      _timeRemaining = _breakSeconds;
      _currentState = TimerSessionState.breakActive;
    }
  }

  /// Handle break session completion
  void _handleBreakComplete() {
    _timeRemaining = _focusSeconds;
    _currentState = TimerSessionState.focusActive;
  }

  /// Reset to idle state
  void _resetToIdle() {
    _currentState = TimerSessionState.idle;
    _activeTask = null;
    _currentCycle = 1;
    _totalCycles = 1;
    _focusSeconds = 0;
    _breakSeconds = 0;
    _timeRemaining = 0;
    _isOverdue = false;
  }

  /// Update time remaining (called by ticker)
  void updateTimeRemaining(int seconds) {
    _timeRemaining = seconds;
  }

  /// Update focused time cache
  void updateFocusedTime(String taskName, int seconds) {
    _focusedTimeCache[taskName] = seconds;
  }

  /// Get focused time for a task
  int getFocusedTime(String taskName) {
    return _focusedTimeCache[taskName] ?? 0;
  }

  /// Mark overdue prompt as shown
  void markOverduePromptShown(String taskName) {
    _overduePromptShown.add(taskName);
  }

  /// Mark task as continued overdue
  void markOverdueContinued(String taskName) {
    _overdueContinued.add(taskName);
  }

  /// Check if overdue prompt was shown
  bool wasOverduePromptShown(String taskName) {
    return _overduePromptShown.contains(taskName);
  }

  /// Check if task was continued overdue
  bool wasOverdueContinued(String taskName) {
    return _overdueContinued.contains(taskName);
  }

  /// Force reset the session controller (for error recovery)
  void forceReset() {
    if (kDebugMode) {
      debugPrint(
        'TIMER_FSM: Force resetting session controller from state: $_currentState',
      );
    }
    _resetToIdle();
  }

  /// Get current session info
  Map<String, dynamic> getSessionInfo() {
    return {
      'state': _currentState.toString(),
      'activeTask': _activeTask,
      'currentCycle': _currentCycle,
      'totalCycles': _totalCycles,
      'timeRemaining': _timeRemaining,
      'isOverdue': _isOverdue,
      'isRunning':
          _currentState == TimerSessionState.focusActive ||
          _currentState == TimerSessionState.breakActive,
      'currentMode':
          _currentState == TimerSessionState.focusActive ||
              _currentState == TimerSessionState.focusPaused
          ? 'focus'
          : 'break',
    };
  }
}
