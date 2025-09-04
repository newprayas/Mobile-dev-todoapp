import 'dart:async';
import '../models/timer_state.dart';

typedef TickCallback = void Function();
typedef PhaseCompleteCallback = void Function();
typedef OverdueCheckCallback = void Function();

/// Foreground ticker responsible solely for per-second updates.
/// NOTE: Kept 100% synchronous to avoid races introduced by async gaps in Timer.periodic.
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
    if (_isRunning) return; // Guard against duplicate timers (double decrement)
    stop();
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final TimerState state = stateProvider();
      if (!state.isRunning) return; // Shallow guard clause

      onOverdueCheck();
      if (state.timeRemaining <= 0) {
        onPhaseComplete();
        return;
      }
      onTick();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }
}
