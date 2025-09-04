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
  bool _isRunning = false;
  bool get isActive => _timer != null && _isRunning;

  void start({
    required TickCallback onTick,
    required PhaseCompleteCallback onPhaseComplete,
    required OverdueCheckCallback onOverdueCheck,
    required TimerState Function() stateProvider,
  }) {
    if (_isRunning) return; // Prevent duplicate timers (double decrement bug)
    stop();
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final TimerState state = stateProvider();
      if (!state.isRunning) return; // Paused; do nothing.

      // Overdue check (side-effect free relative to countdown decrement)
      onOverdueCheck();

      if (state.timeRemaining <= 0) {
        onPhaseComplete();
        return;
      }

      // Single tick callback per second (Notifier handles focus accumulation & decrement)
      onTick();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }
}
