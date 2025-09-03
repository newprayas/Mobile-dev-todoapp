import 'dart:async';
import '../models/timer_state.dart';
import '../../../core/constants/timer_defaults.dart';

typedef TickCallback = void Function();
typedef PhaseCompleteCallback = void Function();
typedef OverdueCheckCallback = void Function();

/// Foreground ticker responsible solely for per-second updates.
/// Keeps Timer creation / disposal separate from business logic in the Notifier.
class ForegroundTicker {
  Timer? _timer;
  bool get isActive => _timer != null;

  void start({
    required TickCallback onTick,
    required PhaseCompleteCallback onPhaseComplete,
    required OverdueCheckCallback onOverdueCheck,
    required TimerState Function() stateProvider,
  }) {
    stop();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final TimerState state = stateProvider();
      if (!state.isRunning) return; // Guard clause

      // Overdue check first (non-destructive)
      onOverdueCheck();

      // Focused time accumulation (only in focus mode & active task)
      if (state.currentMode == 'focus' && state.activeTaskId != null) {
        onTick();
      }

      if (state.timeRemaining > 0) {
        // We let the notifier decrement timeRemaining directly (to persist)
        onTick();
      } else {
        onPhaseComplete();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
