import '../../todo/models/todo.dart';
import '../models/timer_state.dart';

/// Represents the data needed to render/update the persistent timer notification.
class PersistentTimerNotificationModel {
  final String title;
  final String body;
  final List<String> actionIds; // ordered list describing buttons to show
  final bool ongoing; // whether notification should be persistent

  const PersistentTimerNotificationModel({
    required this.title,
    required this.body,
    required this.actionIds,
    required this.ongoing,
  });

  static const String actionPause = 'pause_timer';
  static const String actionResume = 'resume_timer';
  static const String actionStop = 'stop_timer';
  static const String actionMarkComplete = 'mark_complete';
  static const String actionContinueWorking = 'continue_working';

  /// Maps the current timer state + active todo into notification data.
  /// This pure function is intentionally isolated so it can be unit tested
  /// without depending on the platform notification plugin.
  static PersistentTimerNotificationModel fromState({
    required TimerState state,
    required Todo? activeTodo,
  }) {
    final String taskName = activeTodo?.text ?? 'Unknown Task';

    // Scenario: All planned sessions for permanently overdue task complete
    if (state.overdueSessionsComplete) {
      return PersistentTimerNotificationModel(
        title: '✅ SESSIONS COMPLETE',
        body: "You have finished all planned sessions for '$taskName'.",
        actionIds: const [actionMarkComplete, actionContinueWorking],
        ongoing: true,
      );
    }

    // Scenario: Planned time reached first time (progress bar full)
    if (state.isProgressBarFull && !state.overdueSessionsComplete) {
      return PersistentTimerNotificationModel(
        title: 'TIMER IS COMPLETE',
        body: "Planned time for '$taskName' is up.",
        actionIds: const [actionMarkComplete, actionContinueWorking],
        ongoing: true,
      );
    }

    final bool isFocus = state.currentMode == 'focus';

    // Scenario: Permanently overdue active focus session (count-up visual)
    if (state.isPermanentlyOverdue && isFocus && state.isRunning) {
      final int focusDuration = state.focusDurationSeconds ?? 0;
    final int rawElapsed = focusDuration - state.timeRemaining;
    final int elapsed = rawElapsed < 0
      ? 0
      : (rawElapsed > 86400 ? 86400 : rawElapsed); // clamp manually
      final String elapsedStr = _format(elapsed);
      return PersistentTimerNotificationModel(
        title: '🔴 FOCUS TIME',
        body: '$taskName • $elapsedStr',
        actionIds: [state.isRunning ? actionPause : actionResume, actionStop],
        ongoing: true,
      );
    }

    // Standard running / paused session (focus or break)
    final String remaining = _format(state.timeRemaining);
    final String title = isFocus ? '🎯 FOCUS TIME' : '☕ BREAK TIME';
    return PersistentTimerNotificationModel(
      title: title,
      body: '$taskName • $remaining',
      actionIds: state.isRunning
          ? [actionPause, actionStop]
          : [actionResume, actionStop],
      ongoing: true,
    );
  }

  static String _format(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
