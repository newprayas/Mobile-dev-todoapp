import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timer_provider.dart';
import '../../todo/providers/todos_provider.dart';

/// Handles notification action IDs and delegates to notifier methods.
class NotificationActionHandler {
  final TimerNotifier notifier;
  final Ref ref;
  NotificationActionHandler({required this.notifier, required this.ref});

  Future<void> handle(String actionId) async {
    switch (actionId) {
      case 'pause_timer':
        if (notifier.state.isRunning) notifier.pauseTask();
        break;
      case 'resume_timer':
        if (!notifier.state.isRunning) notifier.resumeTask();
        break;
      case 'stop_timer':
        if (notifier.state.activeTaskId != null) {
          await notifier.stopAndSaveProgress(notifier.state.activeTaskId!);
        } else {
          notifier.clear();
        }
        break;
      case 'mark_complete':
        if (notifier.state.activeTaskId != null) {
          await ref.read(todosProvider.notifier).toggleTodo(notifier.state.activeTaskId!);
          await notifier.stopAndSaveProgress(notifier.state.activeTaskId!);
        }
        break;
      case 'continue_working':
        if (notifier.state.activeTaskId != null) {
          notifier.state = notifier.state.copyWith(
            overdueContinued: Set<int>.from(notifier.state.overdueContinued)
              ..add(notifier.state.activeTaskId!),
            isPermanentlyOverdue: true,
            isProgressBarFull: false,
            plannedDurationSeconds: null,
            focusDurationSeconds: null,
          );
          notifier.update(); // trigger persistence/notification
        }
        break;
    }
  }
}
