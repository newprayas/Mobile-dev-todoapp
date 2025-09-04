import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timer_provider.dart';
import '../state_machine/timer_events.dart';
import '../../todo/providers/todos_provider.dart';
import '../models/timer_state.dart';

/// Handles notification action IDs and delegates to notifier methods.
class NotificationActionHandler {
  final TimerNotifier notifier;
  final Ref ref;
  NotificationActionHandler({required this.notifier, required this.ref});

  Future<void> handle(String actionId) async {
    // Take a snapshot of current state via public API (add a getter in notifier if needed)
    final TimerState snapshot = notifier.debugCurrentState;
    switch (actionId) {
      case 'pause_timer':
        if (snapshot.isRunning)
          notifier.emitExternal(const NotificationPauseTappedEvent());
        break;
      case 'resume_timer':
        if (!snapshot.isRunning && snapshot.isTimerActive) {
          notifier.emitExternal(const NotificationResumeTappedEvent());
        }
        break;
      case 'stop_timer':
        notifier.emitExternal(
          NotificationStopTappedEvent(snapshot.activeTaskId),
        );
        break;
      case 'mark_complete':
        if (snapshot.activeTaskId != null) {
          await ref
              .read(todosProvider.notifier)
              .toggleTodo(snapshot.activeTaskId!);
          notifier.emitExternal(
            NotificationStopTappedEvent(snapshot.activeTaskId),
          );
        }
        break;
      case 'continue_working':
        if (snapshot.activeTaskId != null) {
          final int id = snapshot.activeTaskId!;
          final updatedOverdueContinued = Set<int>.from(
            snapshot.overdueContinued,
          )..add(id);
          notifier.update(
            overdueContinued: updatedOverdueContinued,
            isPermanentlyOverdue: true,
            isProgressBarFull: false,
            plannedDurationSeconds: null,
            focusDurationSeconds: null,
          );
        }
        break;
    }
  }
}
