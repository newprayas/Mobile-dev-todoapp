import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/sound_assets.dart';
import '../../../core/utils/debug_logger.dart';
import '../../../core/data/todo_repository.dart';
import '../../todo/providers/todos_provider.dart';
import '../../../core/providers/notification_provider.dart';
import '../providers/timer_provider.dart';

/// Encapsulates overdue detection and handling to reduce complexity in TimerNotifier.
class TimerOverdueService {
  final TimerNotifier notifier;
  final Ref ref;

  TimerOverdueService({required this.notifier, required this.ref});

  void markOverdueAndFreeze(int taskId) {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      final todos = ref.read(todosProvider).value ?? [];
      final task = todos.where((t) => t.id == taskId).toList();
      if (task.isNotEmpty) {
        notificationService.playSoundWithNotification(
          soundFileName: SoundAsset.sessionComplete.fileName,
          title: 'Planned Time Complete!',
          body: 'Time for "${task.first.text}" is up. Decide whether to continue or complete.',
        );
      }
    } catch (e) {
      debugLog('TimerOverdueService', 'Notification error: $e');
    }

    notifier.update(
      isRunning: false,
      timeRemaining: 0,
      isProgressBarFull: true,
      overdueCrossedTaskId: taskId,
      plannedDurationSeconds: null,
      focusDurationSeconds: null,
      breakDurationSeconds: null,
      currentCycle: 1,
      totalCycles: 1,
    );
  }

  Future<void> markTaskPermanentlyOverdue(int taskId, int overdueSeconds) async {
    final repo = ref.read(todoRepositoryProvider);
    await repo.markTaskPermanentlyOverdue(taskId, overdueTime: overdueSeconds);
  }
}
