import 'package:riverpod/riverpod.dart';
import '../models/timer_state.dart';
import 'timer_side_effects.dart';
import '../../../core/services/notification_service.dart';
import '../services/timer_persistence_manager.dart';
import '../../../core/data/todo_repository.dart';
import '../../../core/services/workmanager_timer_service.dart';
import 'dart:async';
import '../../../core/utils/helpers.dart';

/// Executes side effects emitted by the timer reducer in a centralized, testable way.
typedef Reader = T Function<T>(ProviderListenable<T> provider);

class SideEffectRunner {
  final Reader ref;
  final NotificationService _notificationService;
  final TimerPersistenceManager _persistenceManager;
  final WorkmanagerTimerService _wmService = WorkmanagerTimerService();

  SideEffectRunner(
    this.ref, {
    required NotificationService notificationService,
    required TimerPersistenceManager persistenceManager,
  }) : _notificationService = notificationService,
       _persistenceManager = persistenceManager;

  Future<void> run(List<TimerSideEffect> effects, TimerState state) async {
    for (final effect in effects) {
      try {
        if (effect is ShowNotificationEffect) {
          await _handleShowNotification(state);
        } else if (effect is CancelAllNotificationsSideEffect) {
          await _notificationService.cancelPersistentTimerNotification();
        } else if (effect is PersistStateSideEffect ||
            effect is PersistStateEffect) {
          await _persistenceManager.saveTimerState(state);
        } else if (effect is PlaySoundEffect) {
          _notificationService.playSound(effect.asset);
          if (effect.title != null || effect.body != null) {
            _notificationService.showNotification(
              title: effect.title ?? 'Focus Timer',
              body: effect.body ?? '',
            );
          }
        } else if (effect is ScheduleWorkmanagerEffect) {
          await _scheduleWork(effect, state);
        } else if (effect is CancelWorkmanagerEffect) {
          await _wmService.cancelPomodoroTask();
        } else if (effect is PhaseCompleteSideEffect) {
          // Could emit analytics or logging; placeholder for now.
        } else if (effect is OverdueReachedSideEffect) {
          // Overdue-specific notification already captured via ShowNotificationEffect.
        } else if (effect is SaveFocusToRepoEffect) {
          final repo = ref(todoRepositoryProvider);
          await repo.updateFocusTime(effect.taskId, effect.seconds);
        }
      } catch (e, st) {
        // Intentionally swallow to avoid crashing ticker loop; log via provider logger.
        // ignore: avoid_print
        print(
          '[SideEffectRunner] Error executing ${effect.runtimeType}: $e\n$st',
        );
      }
    }
  }

  Future<void> _scheduleWork(
    ScheduleWorkmanagerEffect effect,
    TimerState state,
  ) async {
    if (effect.remainingSeconds <= 0 || !state.isRunning) {
      await _wmService.cancelPomodoroTask();
      return;
    }
    // Provide minimal input needed for background completion; can expand as needed.
    await _wmService.schedulePomodoroOneOff(
      delay: Duration(seconds: effect.remainingSeconds + 5),
      inputData: {
        'activeTaskId': effect.taskId,
        'activeTaskText': effect.taskName,
        'timeRemaining': effect.remainingSeconds,
        'currentMode': state.currentMode,
      },
    );
  }

  Future<void> _handleShowNotification(TimerState state) async {
    if (!state.isTimerActive) {
      await _notificationService.cancelPersistentTimerNotification();
      return;
    }
    final bool running = state.isRunning;
    final String title = running ? '🎯 FOCUS TIME' : '⏸️ PAUSED';
    final String body = state.activeTaskName != null
        ? '${state.activeTaskName} • ${formatTime(state.timeRemaining)}'
        : formatTime(state.timeRemaining);
    final List<String> actions = running
        ? const ['pause_timer', 'stop_timer']
        : const ['resume_timer', 'stop_timer'];
    await _notificationService.showOrUpdatePersistent(
      title: title,
      body: body,
      actionIds: actions,
    );
  }

  // Local _format removed in favor of shared formatTime helper to ensure consistency.
}
