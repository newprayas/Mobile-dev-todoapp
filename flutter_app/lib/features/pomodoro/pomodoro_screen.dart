// SUGGESTED FILE: lib/features/pomodoro/pomodoro_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/utils/app_dialogs.dart';
import '../todo/models/todo.dart';
import '../todo/providers/todos_provider.dart';
import 'providers/timer_provider.dart';
import 'widgets/pomodoro_action_buttons.dart';
import 'widgets/pomodoro_overdue_display.dart';
import 'widgets/pomodoro_setup_view.dart';
import 'widgets/pomodoro_timer_view.dart';

// Define the callback here, making it the single source of truth.
typedef TaskCompletedCallback =
    Future<void> Function({bool wasOverdue, int overdueTime});

class PomodoroScreen extends ConsumerStatefulWidget {
  final ApiService api;
  final Todo todo;
  final NotificationService notificationService;
  final TaskCompletedCallback onTaskCompleted;
  final bool asSheet;

  const PomodoroScreen({
    required this.api,
    required this.todo,
    required this.notificationService,
    required this.onTaskCompleted,
    this.asSheet = false,
    super.key,
  });

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> {
  late TextEditingController _focusController;
  late TextEditingController _breakController;
  late TextEditingController _cyclesController;

  @override
  void initState() {
    super.initState();
    final timerState = ref.read(timerProvider);
    _focusController = TextEditingController(
      text: ((timerState.focusDurationSeconds ?? 1500) ~/ 60).toString(),
    );
    _breakController = TextEditingController(
      text: ((timerState.breakDurationSeconds ?? 300) ~/ 60).toString(),
    );
    _cyclesController = TextEditingController(
      text: timerState.totalCycles.toString(),
    );

    _focusController.addListener(_onDurationsChanged);
    _breakController.addListener(_onDurationsChanged);
    _cyclesController.addListener(_onDurationsChanged);
  }

  void _onDurationsChanged() {
    final focusMinutes = int.tryParse(_focusController.text) ?? 25;
    final breakMinutes = int.tryParse(_breakController.text) ?? 5;

    // *** SMART BUSINESS LOGIC: Auto-calculate cycles based on planned duration ***
    final plannedSeconds =
        (widget.todo.durationHours * 3600) + (widget.todo.durationMinutes * 60);
    int calculatedCycles = 4; // Default cycles
    if (plannedSeconds > 0 && focusMinutes > 0) {
      calculatedCycles = (plannedSeconds / (focusMinutes * 60)).ceil().clamp(
        1,
        1000,
      );
    }

    // Update the text controller without triggering another listener event
    // This prevents infinite loops while keeping UI in sync
    if (_cyclesController.text != calculatedCycles.toString()) {
      _cyclesController.text = calculatedCycles.toString();
    }

    ref
        .read(timerProvider.notifier)
        .updateDurations(
          focusDuration: focusMinutes * 60,
          breakDuration: breakMinutes * 60,
          totalCycles: calculatedCycles, // Use calculated value
        );
  }

  @override
  void dispose() {
    _focusController.removeListener(_onDurationsChanged);
    _breakController.removeListener(_onDurationsChanged);
    _cyclesController.removeListener(_onDurationsChanged);
    _focusController.dispose();
    _breakController.dispose();
    _cyclesController.dispose();
    super.dispose();
  }

  void _handlePlayPause() {
    final notifier = ref.read(timerProvider.notifier);
    final timerState = ref.read(timerProvider);
    if (!timerState.isRunning && timerState.currentCycle == 0) {
      // *** CRITICAL UX VALIDATION: Focus duration cannot exceed task duration ***
      final focusDurationMinutes = int.tryParse(_focusController.text) ?? 25;
      final focusDurationSeconds = focusDurationMinutes * 60;
      final plannedDurationSeconds =
          (widget.todo.durationHours * 3600) +
          (widget.todo.durationMinutes * 60);

      if (plannedDurationSeconds > 0 &&
          focusDurationSeconds > plannedDurationSeconds) {
        // Show validation error dialog
        _showFocusDurationValidationError(
          focusDurationMinutes,
          widget.todo.durationHours,
          widget.todo.durationMinutes,
        );
        return;
      }

      notifier.startTask(
        taskName: widget.todo.text,
        focusDuration: focusDurationSeconds,
        breakDuration: (int.tryParse(_breakController.text) ?? 5) * 60,
        plannedDuration: plannedDurationSeconds,
        totalCycles: int.tryParse(_cyclesController.text) ?? 4,
      );
    } else {
      notifier.toggleRunning();
    }
  }

  void _handleReset() {
    ref.read(timerProvider.notifier).resetCurrentPhase();
  }

  void _handleSkip() {
    ref.read(timerProvider.notifier).skipPhase();
  }

  void _handleStop() async {
    final timerState = ref.read(timerProvider);
    final notifier = ref.read(timerProvider.notifier);

    // Calculate minutes worked in current session
    final totalFocusDuration = timerState.focusDurationSeconds ?? 1500;
    final timeRemaining = timerState.timeRemaining;
    final minutesWorked = ((totalFocusDuration - timeRemaining) / 60).round();

    // *** UX POLISH: Pause timer during dialog interaction ***
    final wasRunning = timerState.isRunning;
    if (wasRunning) {
      notifier.pauseTask();
    }

    // Show stop confirmation dialog
    final shouldStop = await AppDialogs.showStopSessionDialog(
      context: context,
      taskName: widget.todo.text,
      minutesWorked: minutesWorked,
    );

    // *** UX POLISH: Resume timer if user cancels ***
    if (shouldStop != true && wasRunning) {
      notifier.resumeTask();
      return;
    }

    if (shouldStop == true) {
      // Save progress and stop the session
      final success = await ref
          .read(timerProvider.notifier)
          .stopAndSaveProgress(widget.todo.id);

      if (success) {
        // *** UX FEEDBACK: Show progress saved confirmation ***
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Progress saved for "${widget.todo.text}" ✓',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        // Close the Pomodoro screen after successful save
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        // Show error message if save failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to save progress, but session was stopped.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  /// Shows validation error when focus duration exceeds task duration
  void _showFocusDurationValidationError(
    int focusMinutes,
    int taskHours,
    int taskMinutes,
  ) {
    final totalTaskMinutes = (taskHours * 60) + taskMinutes;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Invalid Focus Duration',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          'Focus duration ($focusMinutes minutes) cannot be longer than the total task duration ($totalTaskMinutes minutes).\n\n'
          'Please reduce the focus duration or increase the task duration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Shows overdue prompt when task exceeds planned duration with new UX flow
  void _showOverduePrompt(
    BuildContext context,
    WidgetRef ref,
    TimerNotifier timerNotifier,
  ) async {
    // Mark prompt as shown to prevent re-triggering
    timerNotifier.markOverduePromptShown(widget.todo.text);

    final wasRunning = ref.read(timerProvider).isRunning;
    if (wasRunning) timerNotifier.pauseTask();

    final result = await AppDialogs.showOverdueDialog(
      context: context,
      taskName: widget.todo.text,
    );

    if (!mounted) return;

    if (result == true) {
      // User chose "Mark Complete"
      final focusedTime = timerNotifier.getFocusedTime(widget.todo.text);
      final plannedTime =
          (widget.todo.durationHours * 3600) +
          (widget.todo.durationMinutes * 60);
      final overdueTime = (focusedTime - plannedTime)
          .clamp(0, double.infinity)
          .toInt();

      // Use the dedicated completion method instead of the callback
      try {
        await ref
            .read(todosProvider.notifier)
            .completeTodoWithOverdue(widget.todo.id, overdueTime: overdueTime);
        timerNotifier.clear();
        Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to complete task. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else if (result == false) {
      // User chose "Continue"
      // *** FIXED UX FLOW: Stop timer completely and hide minibar ***
      final success = await timerNotifier.stopAndSaveProgress(widget.todo.id);

      // Clear the timer completely to hide minibar
      timerNotifier.clear();

      // Optimistically mark task permanently overdue in local state so when
      // user returns to list it's already in overdue mode.
      final focusedTime = timerNotifier.getFocusedTime(widget.todo.text);
      final plannedTime =
          (widget.todo.durationHours * 3600) +
          (widget.todo.durationMinutes * 60);
      final overdueTime = (focusedTime - plannedTime)
          .clamp(0, double.infinity)
          .toInt();
      ref
          .read(todosProvider.notifier)
          .markTaskPermanentlyOverdue(widget.todo.id, overdueTime: overdueTime);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Progress saved. Press play on the task to continue.'
                  : 'Session stopped (save failed).',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: success ? Colors.green[700] : Colors.orange[700],
          ),
        );
        Navigator.of(context).pop();
      }
    } else {
      // Dialog was dismissed
      if (wasRunning) timerNotifier.resumeTask();
    }
  }

  void _showAllSessionsCompleteDialog(BuildContext context, int totalCycles) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sessions Complete!'),
        content: Text(
          'Congratulations! You have completed all $totalCycles focus sessions for "${widget.todo.text}".',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Clear the flag after showing the dialog
              ref.read(timerProvider.notifier).clearAllSessionsCompleteFlag();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brightYellow,
              foregroundColor: Colors.black,
            ),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // *** SMART BUSINESS LOGIC: Listen for timer state changes ***
    ref.listen<TimerState>(timerProvider, (previous, next) {
      // Show dialog when all sessions complete
      if (next.allSessionsComplete &&
          !(previous?.allSessionsComplete ?? false)) {
        _showAllSessionsCompleteDialog(context, next.totalCycles);
      }

      // *** UX FEEDBACK: Show blocked action feedback ***
      if (next.cycleOverflowBlocked &&
          !(previous?.cycleOverflowBlocked ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot set more than ${next.totalCycles} cycles for this task duration',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // *** NEW UX FLOW: Handle overdue prompt ***
      if (next.overdueCrossedTaskName == widget.todo.text &&
          !next.overduePromptShown.contains(widget.todo.text)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            _showOverduePrompt(context, ref, ref.read(timerProvider.notifier));
          }
        });
      }
    });

    final timerState = ref.watch(timerProvider);
    final isSetupMode = !timerState.isRunning && timerState.currentCycle == 0;

    final focusedSeconds =
        timerState.focusedTimeCache[widget.todo.text] ??
        widget.todo.focusedTime;
    final plannedSeconds =
        (widget.todo.durationHours * 3600) + (widget.todo.durationMinutes * 60);

    // *** NEW OVERDUE MODE LOGIC: Check for permanent overdue state ***
    final isPermanentOverdueMode = widget.todo.wasOverdue == 1;
    final isCurrentSessionOverdue =
        plannedSeconds > 0 && focusedSeconds >= plannedSeconds;
    final shouldShowOverdueDisplay =
        isPermanentOverdueMode || isCurrentSessionOverdue;

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (widget.asSheet)
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          const SizedBox(height: 16),
          Column(
            children: [
              Text(
                widget.todo.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.brightYellow,
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isPermanentOverdueMode) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: const Text(
                    '🔴 OVERDUE MODE',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 28,
            child: shouldShowOverdueDisplay
                ? PomodoroOverdueDisplay(
                    focusedSeconds: focusedSeconds,
                    plannedSeconds: plannedSeconds,
                    isPermanentOverdueMode: isPermanentOverdueMode,
                  )
                : ProgressBar(
                    focusedSeconds: focusedSeconds,
                    plannedSeconds: plannedSeconds,
                    barHeight: 28,
                  ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isSetupMode
                  ? PomodoroSetupView(
                      key: const ValueKey('setup'),
                      focusController: _focusController,
                      breakController: _breakController,
                      cyclesController: _cyclesController,
                      onFocusChanged: (val) {},
                      onBreakChanged: (val) {},
                    )
                  : PomodoroTimerView(
                      key: const ValueKey('timer'),
                      timerState: timerState,
                    ),
            ),
          ),
          const SizedBox(height: 20),
          PomodoroActionButtons(
            timerState: timerState,
            onPlayPause: _handlePlayPause,
            onReset: _handleReset,
            onSkip: _handleSkip,
            onStop: _handleStop, // Add stop functionality
          ),
        ],
      ),
    );
  }
}
