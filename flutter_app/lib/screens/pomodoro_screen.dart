import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/todo.dart';
import '../theme/app_colors.dart';
import '../services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/timer_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/progress_bar.dart';
import '../utils/app_dialogs.dart';

// Callback to let the parent (TodoListScreen) know the task was completed.
typedef TaskCompletedCallback = Future<void> Function();

class PomodoroScreen extends ConsumerStatefulWidget {
  final ApiService api;
  final Todo todo;
  final NotificationService notificationService;
  final bool asSheet;
  final TaskCompletedCallback onTaskCompleted;

  const PomodoroScreen({
    required this.api,
    required this.todo,
    required this.notificationService,
    this.asSheet = false,
    required this.onTaskCompleted,
    super.key,
  });

  // Keep the static method here
  static Future<void> showAsBottomSheet(
    BuildContext context,
    ApiService api,
    Todo todo,
    NotificationService notificationService,
    TaskCompletedCallback onTaskCompleted,
  ) async {
    // Function to handle sheet dismissal and update minibar
    void updateMinibar() {
      final container = ProviderScope.containerOf(context);
      final timerState = container.read(timerProvider);
      final timerNotifier = container.read(timerProvider.notifier);
      if (kDebugMode) {
        debugPrint(
          'POMODORO: Transitioning to mini-bar - running=${timerState.isRunning} mode=${timerState.currentMode}',
        );
      }
      if (timerState.activeTaskName == null && !timerState.isRunning) {
        if (kDebugMode) {
          debugPrint('POMODORO: minibar suppressed because provider cleared');
        }
        return;
      }
      // Ensure this task is reflected as active and show minibar.
      timerNotifier.update(
        taskName: todo.text,
        remaining: timerState.timeRemaining,
        running: timerState.isRunning,
        mode: timerState.currentMode,
        active: true,
      );
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.8,
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) {
                updateMinibar();
              }
            },
            child: GestureDetector(
              onTap: () {},
              child: PomodoroScreen(
                api: api,
                todo: todo,
                notificationService: notificationService,
                asSheet: true,
                onTaskCompleted: onTaskCompleted,
              ),
            ),
          ),
        ),
      ),
    );

    // Handle swipe-to-dismiss
    updateMinibar();
  }

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> {
  // Declare the controllers as late final members of the state class.
  late final TextEditingController _focusController;
  late final TextEditingController _breakController;
  late final TextEditingController _cyclesController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with default values - will sync with state in first build
    _focusController = TextEditingController(text: '25');
    _breakController = TextEditingController(text: '5');
    _cyclesController = TextEditingController(text: '4');
  }

  @override
  void dispose() {
    // Dispose of the controllers to prevent memory leaks.
    _focusController.dispose();
    _breakController.dispose();
    _cyclesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerProvider);
    final timerNotifier = ref.read(timerProvider.notifier);

    // Handle overdue prompt when overdue is detected
    if (timerState.overdueCrossedTaskName == widget.todo.text &&
        !timerNotifier.hasOverduePromptBeenShown(widget.todo.text)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _showOverduePrompt(context, ref, timerNotifier);
        }
      });
    }

    // Handle progress bar full
    if (timerState.isProgressBarFull) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _showProgressBarFullDialog(context, ref, timerNotifier);
        }
      });
    }

    // Handle session completion
    if (timerState.allSessionsComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _showSessionCompletionDialog(context, ref, timerNotifier);
        }
      });
    }

    final isSetupMode =
        !timerState.isRunning &&
        (timerState.timeRemaining == timerState.focusDurationSeconds ||
            timerState.timeRemaining == 0);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      'Pomodoro Timer',
                      style: TextStyle(
                        color: AppColors.brightYellow,
                        fontSize: 22.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        // Pause timer while dialog is shown (as per UX flow)
                        final wasRunning = timerState.isRunning;
                        if (wasRunning) {
                          timerNotifier.deactivate();
                        }

                        // Calculate progress for this interval
                        final focusedTime = timerNotifier.getFocusedTime(
                          widget.todo.text,
                        );
                        final minutesWorked = (focusedTime / 60).round();

                        final shouldStop =
                            await AppDialogs.showStopSessionDialog(
                              context: context,
                              taskName: widget.todo.text,
                              minutesWorked: minutesWorked,
                            );

                        if (shouldStop == true) {
                          // Stop & Save - terminate session and close
                          timerNotifier.clear();
                          if (mounted && context.mounted) {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          }
                        } else {
                          // Cancel - resume timer if it was running
                          if (wasRunning) {
                            timerNotifier.resumeTask();
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.brightYellow, width: 1.5),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  widget.todo.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
              Builder(
                builder: (ctx) {
                  final plannedSeconds =
                      (widget.todo.durationHours * 3600) +
                      (widget.todo.durationMinutes * 60);
                  final cached = timerNotifier.getFocusedTime(widget.todo.text);
                  final isOverdueTask =
                      plannedSeconds > 0 &&
                      cached >= plannedSeconds &&
                      timerNotifier.hasUserContinuedOverdue(widget.todo.text);

                  return Padding(
                    padding: const EdgeInsets.only(top: 48.0, bottom: 8.0),
                    child: SizedBox(
                      height: 34,
                      child: isOverdueTask
                          ? _buildOverdueTimeDisplay(cached, plannedSeconds)
                          : ProgressBar(
                              focusedSeconds: cached,
                              plannedSeconds: plannedSeconds,
                              barHeight: 28.0,
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
          Expanded(
            child: isSetupMode
                ? _buildSetupUI(context, ref, timerState, timerNotifier)
                : _buildRunningUI(context, ref, timerState, timerNotifier),
          ),
          _buildActionButtons(context, ref, timerState, timerNotifier),
        ],
      ),
    );
  }

  Widget _buildSetupUI(
    BuildContext context,
    WidgetRef ref,
    TimerState timerState,
    TimerNotifier timerNotifier,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: Colors.grey.shade700, width: 1.0),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: TextField(
                    controller: _focusController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18.0, color: Colors.white),
                    decoration: const InputDecoration(border: InputBorder.none),
                    onChanged: (value) {
                      final intValue = int.tryParse(value) ?? 25;
                      timerNotifier.updateDurations(
                        focusDuration: intValue * 60,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Container(width: 2, height: 56, color: AppColors.brightYellow),
                const SizedBox(height: 12),
                const Text(
                  'Work Duration',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: AppColors.brightYellow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Break Time',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: AppColors.brightYellow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(width: 2, height: 56, color: AppColors.brightYellow),
                const SizedBox(height: 12),
                Container(
                  width: 88,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: Colors.grey.shade700, width: 1.0),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: TextField(
                    controller: _breakController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18.0, color: Colors.white),
                    decoration: const InputDecoration(border: InputBorder.none),
                    onChanged: (value) {
                      final intValue = int.tryParse(value) ?? 5;
                      timerNotifier.updateDurations(
                        breakDuration: intValue * 60,
                      );
                    },
                  ),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: Colors.grey.shade700, width: 1.0),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: TextField(
                    controller: _cyclesController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18.0, color: Colors.white),
                    decoration: const InputDecoration(border: InputBorder.none),
                    onChanged: (value) {
                      final intValue = int.tryParse(value) ?? 4;
                      timerNotifier.updateDurations(totalCycles: intValue);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Container(width: 2, height: 56, color: AppColors.brightYellow),
                const SizedBox(height: 12),
                const Text(
                  'Cycles',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: AppColors.brightYellow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRunningUI(
    BuildContext context,
    WidgetRef ref,
    TimerState timerState,
    TimerNotifier timerNotifier,
  ) {
    String formatTime(int seconds) {
      final m = (seconds ~/ 60).toString().padLeft(2, '0');
      final s = (seconds % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Column(
      children: [
        Text(
          '${(timerState.focusDurationSeconds ?? 1500) ~/ 60} / ${(timerState.breakDurationSeconds ?? 300) ~/ 60} / ${timerState.totalCycles}',
          style: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${timerState.currentCycle} / ${timerState.totalCycles}',
              style: const TextStyle(
                fontSize: 28.0,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: Color(0xFF262626)),
        const SizedBox(height: 12),
        Flexible(
          flex: 5,
          fit: FlexFit.loose,
          child: Center(
            child: IntrinsicWidth(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: (timerState.isRunning || timerState.isTimerActive)
                        ? (timerState.currentMode == 'focus'
                              ? Colors.redAccent
                              : Colors.greenAccent)
                        : Colors.transparent,
                    width: 6.0,
                  ),
                  borderRadius: BorderRadius.circular(14.0),
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    formatTime(timerState.timeRemaining),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.oswald(
                      fontSize: 120.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2.0,
                      height: 1.05,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Divider(color: Color(0xFF262626)),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    TimerState timerState,
    TimerNotifier timerNotifier,
  ) {
    final isRunning = timerState.isRunning;
    final isSetupMode =
        !timerState.isRunning &&
        (timerState.timeRemaining == timerState.focusDurationSeconds ||
            timerState.timeRemaining == 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.brightYellow,
                      width: 2.0,
                    ),
                  ),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: const CircleBorder(),
                      side: BorderSide(color: Colors.transparent),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: () {
                      timerNotifier.resetCurrentPhase();
                    },
                    child: const Icon(
                      Icons.replay_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reset',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: FloatingActionButton(
                    backgroundColor: AppColors.brightYellow,
                    onPressed: () async {
                      if (isSetupMode) {
                        // Validate focus duration before starting
                        final focusDuration =
                            timerState.focusDurationSeconds ?? 25 * 60;
                        final breakDuration =
                            timerState.breakDurationSeconds ?? 5 * 60;
                        final plannedDuration =
                            (widget.todo.durationHours * 3600) +
                            (widget.todo.durationMinutes * 60);
                        final totalCycles = timerState.totalCycles;

                        // Critical validation: Focus duration cannot exceed planned duration
                        if (plannedDuration > 0 &&
                            focusDuration > plannedDuration) {
                          if (kDebugMode) {
                            debugPrint(
                              'VALIDATION: Focus duration ($focusDuration) exceeds planned duration ($plannedDuration)',
                            );
                          }

                          await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Invalid Focus Duration'),
                              content: Text(
                                'Focus duration (${(focusDuration / 60).round()} minutes) cannot be longer than the planned task duration (${(plannedDuration / 60).round()} minutes).\n\nPlease adjust the focus duration to be ${(plannedDuration / 60).round()} minutes or less.',
                              ),
                              actions: [
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brightYellow,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                          return; // Don't start the timer
                        }

                        // Start the timer
                        final started = timerNotifier.startTask(
                          taskName: widget.todo.text,
                          focusDuration: focusDuration,
                          breakDuration: breakDuration,
                          plannedDuration: plannedDuration,
                          totalCycles: totalCycles,
                        );

                        // Only play sound and show notification if timer started successfully
                        if (started) {
                          try {
                            widget.notificationService.showNotification(
                              title: 'Focus Started',
                              body: 'Stay on task: "${widget.todo.text}"',
                            );
                            widget.notificationService.playSound(
                              'focus_timer_start.wav',
                            );
                          } catch (e) {
                            if (kDebugMode) debugPrint('SOUND ERROR: $e');
                          }
                        }
                      } else {
                        // Pause/Resume
                        if (isRunning) {
                          timerNotifier.pauseTask();
                        } else {
                          timerNotifier.resumeTask();
                        }
                      }
                    },
                    child: Icon(
                      isSetupMode
                          ? Icons.play_arrow_rounded
                          : (isRunning
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                      color: Colors.black,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isSetupMode ? 'Start' : (isRunning ? 'Pause' : 'Resume'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.brightYellow,
                      width: 2.0,
                    ),
                  ),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: const CircleBorder(),
                      side: BorderSide(color: Colors.transparent),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: () {
                      timerNotifier.skipPhase();
                    },
                    child: const Icon(
                      Icons.fast_forward_rounded,
                      color: AppColors.brightYellow,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOverdueTimeDisplay(int focusedSeconds, int plannedSeconds) {
    final overdueSeconds = focusedSeconds - plannedSeconds;
    final hours = overdueSeconds ~/ 3600;
    final minutes = (overdueSeconds % 3600) ~/ 60;
    final seconds = overdueSeconds % 60;

    String timeText;
    if (hours > 0) {
      timeText =
          '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      timeText = '$minutes:${seconds.toString().padLeft(2, '0')}';
    }

    return Container(
      height: 28.0,
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: Colors.red, width: 1.0),
      ),
      child: Center(
        child: Text(
          'OVERDUE TIME: $timeText',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showOverduePrompt(
    BuildContext context,
    WidgetRef ref,
    TimerNotifier timerNotifier,
  ) async {
    final timerState = ref.read(timerProvider);
    timerNotifier.markOverduePromptShown(widget.todo.text);
    timerNotifier.deactivate();

    widget.notificationService.showNotification(
      title: 'Task Overdue',
      body: 'Planned time for "${widget.todo.text}" is complete.',
    );

    try {
      widget.notificationService.playSound('progress_bar_full.wav');
    } catch (e) {
      if (kDebugMode) debugPrint('SOUND ERROR: $e');
    }

    final result = await AppDialogs.showOverdueDialog(
      context: context,
      taskName: widget.todo.text,
    );

    if (result == true) {
      // Mark Complete
      widget.onTaskCompleted();
      timerNotifier.clear();
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      // Continue
      timerNotifier.markUserContinuedOverdue(widget.todo.text);
      timerNotifier.resetForSetupWithTask(
        taskName: widget.todo.text,
        focusDuration: timerState.focusDurationSeconds ?? 25 * 60,
        breakDuration: timerState.breakDurationSeconds ?? 5 * 60,
        totalCycles: timerState.totalCycles,
        plannedDuration:
            (widget.todo.durationHours * 3600) +
            (widget.todo.durationMinutes * 60),
      );
    }
  }

  void _showProgressBarFullDialog(
    BuildContext context,
    WidgetRef ref,
    TimerNotifier timerNotifier,
  ) {
    timerNotifier.deactivate();
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    Future.microtask(() {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Progress Bar Full!'),
            content: const Text(
              'You have completed your planned time for this task. The timer has been reset. What would you like to do?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleContinueWorking(context, ref, timerNotifier);
                },
                child: const Text('Continue Working'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleMarkComplete(context, ref, timerNotifier);
                },
                child: const Text('Mark Complete'),
              ),
            ],
          ),
        );
      }
    });
  }

  void _handleContinueWorking(
    BuildContext context,
    WidgetRef ref,
    TimerNotifier timerNotifier,
  ) {
    final timerState = ref.read(timerProvider);
    timerNotifier.resetForSetupWithTask(
      taskName: widget.todo.text,
      focusDuration: timerState.focusDurationSeconds ?? 25 * 60,
      breakDuration: timerState.breakDurationSeconds ?? 5 * 60,
      totalCycles: timerState.totalCycles,
      plannedDuration:
          (widget.todo.durationHours * 3600) +
          (widget.todo.durationMinutes * 60),
    );
  }

  void _handleMarkComplete(
    BuildContext context,
    WidgetRef ref,
    TimerNotifier timerNotifier,
  ) {
    timerNotifier.clear();
    widget.onTaskCompleted();
    Navigator.of(context).pop();
  }

  void _showSessionCompletionDialog(
    BuildContext context,
    WidgetRef ref,
    TimerNotifier timerNotifier,
  ) async {
    final timerState = ref.read(timerProvider);
    timerNotifier.stop();

    if (!context.mounted) return;

    await AppDialogs.showAllSessionsCompleteDialog(
      context: context,
      totalCycles: timerState.totalCycles,
    );

    if (context.mounted) {
      _handleDismissTimer(context, ref, timerNotifier);
    }
  }

  void _handleDismissTimer(
    BuildContext context,
    WidgetRef ref,
    TimerNotifier timerNotifier,
  ) {
    timerNotifier.clear();
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
