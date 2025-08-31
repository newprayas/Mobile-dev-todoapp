import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/utils/app_dialogs.dart';
import '../todo/models/todo.dart';
import 'providers/timer_provider.dart';
import 'widgets/pomodoro_action_buttons.dart';
import 'widgets/pomodoro_setup_view.dart';
import 'widgets/pomodoro_timer_view.dart';

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

    final plannedSeconds =
        (widget.todo.durationHours * 3600) + (widget.todo.durationMinutes * 60);
    int calculatedCycles = 4;
    if (plannedSeconds > 0 && focusMinutes > 0) {
      calculatedCycles = (plannedSeconds / (focusMinutes * 60)).ceil().clamp(
        1,
        1000,
      );
    }

    if (_cyclesController.text != calculatedCycles.toString()) {
      _cyclesController.text = calculatedCycles.toString();
    }

    ref
        .read(timerProvider.notifier)
        .updateDurations(
          focusDuration: focusMinutes * 60,
          breakDuration: breakMinutes * 60,
          totalCycles: calculatedCycles,
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
      final focusDurationMinutes = int.tryParse(_focusController.text) ?? 25;
      final focusDurationSeconds = focusDurationMinutes * 60;
      final plannedDurationSeconds =
          (widget.todo.durationHours * 3600) +
          (widget.todo.durationMinutes * 60);

      final isPermanentOverdueMode = widget.todo.wasOverdue == 1;
      if (!isPermanentOverdueMode &&
          plannedDurationSeconds > 0 &&
          focusDurationSeconds > plannedDurationSeconds) {
        _showFocusDurationValidationError(
          focusDurationMinutes,
          widget.todo.durationHours,
          widget.todo.durationMinutes,
        );
        return;
      }

      notifier.startTask(
        taskId: widget.todo.id,
        taskName: widget.todo.text,
        focusDuration: focusDurationSeconds,
        breakDuration: (int.tryParse(_breakController.text) ?? 5) * 60,
        plannedDuration: plannedDurationSeconds,
        totalCycles: int.tryParse(_cyclesController.text) ?? 4,
        isPermanentlyOverdue: isPermanentOverdueMode,
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

  Future<void> _handleStop() async {
    final notifier = ref.read(timerProvider.notifier);
    final timerState = ref.read(timerProvider);

    if (timerState.activeTaskId == null) {
      notifier.clear();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final wasRunning = timerState.isRunning;
    if (wasRunning) notifier.pauseTask();

    final phaseDuration = timerState.currentMode == 'focus'
        ? (timerState.focusDurationSeconds ?? 0)
        : (timerState.breakDurationSeconds ?? 0);
    final elapsedInPhase = phaseDuration - timerState.timeRemaining;
    final minutesWorkedThisInterval = (elapsedInPhase / 60).round();

    final shouldStop = await AppDialogs.showStopSessionDialog(
      context: context,
      taskName: widget.todo.text,
      minutesWorked: minutesWorkedThisInterval,
    );

    if (!mounted) return;

    if (shouldStop == true) {
      await notifier.stopAndSaveProgress(widget.todo.id);
      Navigator.of(context).pop();
    } else {
      if (wasRunning) notifier.resumeTask();
    }
  }

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
          'Focus duration ($focusMinutes minutes) cannot be longer than the total task duration ($totalTaskMinutes minutes).\n\nPlease reduce the focus duration or increase the task duration.',
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

  void _showAllSessionsCompleteDialog(BuildContext context, int totalCycles) {
    AppDialogs.showAllSessionsCompleteDialog(
      context: context,
      totalCycles: totalCycles,
    ).then((_) {
      ref.read(timerProvider.notifier).clearAllSessionsCompleteFlag();
    });
  }

  Widget _buildStatusIndicator({
    required bool isPermanentOverdue,
    required bool isSetupMode,
    required int focusedSeconds,
    required int plannedSeconds,
  }) {
    final content = isPermanentOverdue
        ? _buildOverdueText(focusedSeconds, plannedSeconds)
        : ProgressBar(
            focusedSeconds: focusedSeconds,
            plannedSeconds: plannedSeconds,
            barHeight: 24.0, // Thicker
          );

    return Padding(
      // Move down in setup mode
      padding: EdgeInsets.only(top: isSetupMode ? 16.0 : 0),
      child: SizedBox(height: 28.0, child: content),
    );
  }

  Widget _buildOverdueText(int focusedSeconds, int plannedSeconds) {
    final overdueSeconds = (focusedSeconds - plannedSeconds)
        .clamp(0, 99999)
        .toInt();
    final minutes = (overdueSeconds ~/ 60).toString();
    final seconds = (overdueSeconds % 60).toString().padLeft(2, '0');

    return Center(
      child: Text(
        'OVERDUE TIME: $minutes:$seconds',
        style: const TextStyle(
          color: AppColors.priorityHigh,
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TimerState>(timerProvider, (previous, next) {
      if (next.allSessionsComplete &&
          !(previous?.allSessionsComplete ?? false)) {
        _showAllSessionsCompleteDialog(context, next.totalCycles);
      }

      // ADD THIS BLOCK
      if (next.overdueSessionsComplete &&
          !(previous?.overdueSessionsComplete ?? false)) {
        debugPrint(
          "POMODORO_SCREEN: Detected overdueSessionsComplete. Popping.",
        );
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // CHANGE: No return value needed
        }
      }
      // END OF ADDED BLOCK

      if (next.cycleOverflowBlocked &&
          !(previous?.cycleOverflowBlocked ?? false)) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Action Not Allowed'),
            content: Text(
              'Cannot set more than ${next.totalCycles} cycles for this task duration.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ref
                      .read(timerProvider.notifier)
                      .clearCycleOverflowBlockedFlag();
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }
    });

    final timerState = ref.watch(timerProvider);
    final isSetupMode = !timerState.isRunning && timerState.currentCycle == 0;

    final focusedSeconds =
        timerState.focusedTimeCache[widget.todo.id] ?? widget.todo.focusedTime;
    final plannedSeconds =
        (widget.todo.durationHours * 3600) + (widget.todo.durationMinutes * 60);

    final isPermanentOverdueMode = widget.todo.wasOverdue == 1;

    return Stack(
      children: [
        Padding(
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
              const SizedBox(height: 50), // Increased top space from 32
              Text(
                widget.todo.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.brightYellow,
                  fontSize: 26.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 20),
              _buildStatusIndicator(
                isPermanentOverdue: isPermanentOverdueMode,
                isSetupMode: isSetupMode,
                focusedSeconds: focusedSeconds,
                plannedSeconds: plannedSeconds,
              ),
              const SizedBox(height: 30),
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
              ),
            ],
          ),
        ),
        if (!isSetupMode)
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: _handleStop,
            ),
          ),
      ],
    );
  }
}
