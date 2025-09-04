import 'dart:async';
import '../models/timer_state.dart';
import '../../../core/constants/timer_defaults.dart';

typedef TickCallback = void Function();
typedef PhaseCompleteCallback = void Function();
typedef OverdueCheckCallback = void Function();
typedef PollNotificationActionsCallback = Future<void> Function();

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
    PollNotificationActionsCallback? onPollNotificationActions,
  }) {
    if (_isRunning) return; // Prevent duplicate timers (double decrement bug)
    stop();
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Poll background notification actions FIRST (must run even when paused)
      // We intentionally do not await to avoid blocking tick scheduling.
      if (onPollNotificationActions != null) {
        try {
          onPollNotificationActions();
        } catch (_) {
          // Swallow errors; polling failures must not stop ticker.
        }
      }

      final TimerState state = stateProvider();
      if (!state.isRunning)
        return; // Paused; skip decrement logic but still polled above.

      // Overdue check (side-effect free relative to countdown decrement)
      onOverdueCheck();

      if (state.timeRemaining <= 0) {
        onPhaseComplete();
        return;
      }

      // Single tick callback per second after polling + overdue + phase logic.
      onTick();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }
}
