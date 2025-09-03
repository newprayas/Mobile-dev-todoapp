import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/sound_assets.dart';
import '../../../core/providers/notification_provider.dart';
import '../models/timer_state.dart';
import '../providers/timer_provider.dart';
import '../../../core/utils/debug_logger.dart';

/// Handles transitions at phase boundaries (focus->break, break->focus, completion states).
class PhaseTransitionService {
  final TimerNotifier notifier;
  final Ref ref;
  PhaseTransitionService({required this.notifier, required this.ref});

  void handlePhaseCompletion(TimerState current) {
    if (current.currentMode == 'focus') {
      _handleFocusCompletion(current);
    } else if (current.currentMode == 'break') {
      _handleBreakCompletion(current);
    } else {
      notifier.stop();
    }
  }

  void skipPhase(TimerState state) {
    final notificationService = ref.read(notificationServiceProvider);
    if (state.currentMode == 'focus') {
      if (state.currentCycle >= state.totalCycles) {
        notifier.update(cycleOverflowBlocked: true);
        return;
      }
      notificationService.playSoundWithNotification(
        soundFileName: SoundAsset.breakStart.fileName,
        title: 'Focus Phase Skipped',
        body: 'Moving to break time for "${state.activeTaskName}".',
      );
      final int completed = state.completedSessions + 1;
      final int nextCycle = state.currentCycle + 1;
      notifier.update(
        currentMode: 'break',
        timeRemaining: state.breakDurationSeconds ?? state.timeRemaining,
        completedSessions: completed,
        currentCycle: nextCycle,
      );
    } else if (state.currentMode == 'break') {
      notificationService.playSound(SoundAsset.focusStart.fileName);
      notifier.update(
        currentMode: 'focus',
        timeRemaining: state.focusDurationSeconds ?? state.timeRemaining,
      );
    }
  }

  void _handleFocusCompletion(TimerState state) {
    final int completed = state.completedSessions + 1;
    if (completed >= state.totalCycles) {
      final service = ref.read(notificationServiceProvider);
      if (state.isPermanentlyOverdue && !state.overdueSessionsComplete) {
        service.playSoundWithNotification(
          soundFileName: SoundAsset.sessionComplete.fileName,
          title: 'Session Complete!',
          body: 'Overdue task session completed for "${state.activeTaskName}".',
        );
        notifier.update(
          overdueSessionsComplete: true,
          isRunning: false,
          completedSessions: completed,
        );
        notifier.stopTicker();
      } else if (!state.allSessionsComplete) {
        service.playSoundWithNotification(
          soundFileName: SoundAsset.sessionComplete.fileName,
          title: 'All Sessions Complete!',
          body: 'All planned sessions completed for "${state.activeTaskName}".',
        );
        notifier.update(
          allSessionsComplete: true,
          isRunning: false,
          completedSessions: completed,
        );
        notifier.stopTicker();
      }
      if (!notifier.state.isRunning && notifier.state.timeRemaining == 0) {
        notifier.stopTicker();
        return;
      }
    } else {
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.playSoundWithNotification(
        soundFileName: SoundAsset.breakStart.fileName,
        title: 'Focus Session Complete!',
        body: 'Time for a break for "${state.activeTaskName}".',
      );
      final int nextCycle = (state.currentCycle + 1) <= state.totalCycles
          ? state.currentCycle + 1
          : state.totalCycles;
      notifier.update(
        currentMode: 'break',
        timeRemaining: state.breakDurationSeconds,
        currentCycle: nextCycle,
        completedSessions: completed,
      );
    }
  }

  void _handleBreakCompletion(TimerState state) {
    if (state.focusDurationSeconds != null) {
      final service = ref.read(notificationServiceProvider);
      service.playSound(SoundAsset.focusStart.fileName);
      service.showNotification(
        title: 'Break Complete!',
        body: 'Time to focus on "${state.activeTaskName}" again!',
      );
      notifier.update(
        currentMode: 'focus',
        timeRemaining: state.focusDurationSeconds,
      );
    } else {
      notifier.stop();
    }
  }
}
