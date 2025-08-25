import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/todo.dart';
import '../theme/app_colors.dart';
import '../services/local_timer_store.dart';
import '../models/task_timer_state.dart';
import '../services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/timer_service.dart';
import '../widgets/progress_bar.dart';

// Callback to let the parent (TodoListScreen) know the task was completed.
typedef TaskCompletedCallback = Future<void> Function();

class PomodoroScreen extends StatefulWidget {
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

  static Future<void> showAsBottomSheet(
    BuildContext context,
    ApiService api,
    Todo todo,
    NotificationService notificationService,
    TaskCompletedCallback onTaskCompleted,
  ) async {
    // Function to handle sheet dismissal and update minibar
    void updateMinibar() {
      final svc = TimerService.instance;
      if (kDebugMode) {
        debugPrint(
          'POMODORO: Transitioning to mini-bar - running=${svc.isRunning} mode=${svc.currentMode}',
        );
      }
      // If the central service has just been cleared (no active task and not running),
      // do not re-open the mini-bar. This prevents the close (X) button from hiding
      // the sheet then immediately re-showing the minibar.
      if (svc.activeTaskName == null && svc.isRunning == false) {
        if (kDebugMode) {
          debugPrint('POMODORO: minibar suppressed because service cleared');
        }
        return;
      }

      // Otherwise, update the mini-bar with current state to ensure smooth transition
      svc.update(
        taskName: todo.text,
        remaining: svc.timeRemaining,
        running: svc.isRunning, // Preserve the running state
        mode: svc.currentMode, // Preserve focus/break mode
        active: true, // Show the mini-bar
      );
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Keep the system sheet background transparent so our container
      // can render a fully opaque styled surface at 80% height.
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
            onPopInvoked: (didPop) {
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
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  final LocalTimerStore _store = LocalTimerStore();
  TaskTimerState? _state;
  Timer? _ticker;
  bool _overduePromptShown = false;
  bool _suppressServiceReactions = false;

  late TextEditingController _focusController;
  late TextEditingController _breakController;
  late TextEditingController _cyclesController;

  @override
  void initState() {
    super.initState();
    _loadState();
    // Post all service interactions to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // mark the mini-bar inactive while the full sheet is open
      TimerService.instance.update(active: false);
      // listen to central timer service so mini-bar controls can affect this screen
      TimerService.instance.addListener(_onServiceUpdate);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _focusController.dispose();
    _breakController.dispose();
    _cyclesController.dispose();
    TimerService.instance.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (kDebugMode) {
      debugPrint('POMODORO: service update received, checking conditions:');
      debugPrint('- Suppression active: $_suppressServiceReactions');
      debugPrint('- State exists: ${_state != null}');
      debugPrint('- Service task: ${TimerService.instance.activeTaskName}');
      debugPrint('- Current task: ${widget.todo.text}');
    }

    // Optionally suppress rapid service reactions right after load/open to avoid races
    if (_suppressServiceReactions) {
      if (kDebugMode) {
        debugPrint(
          'POMODORO: ignoring service update due to suppression window',
        );
      }
      return;
    }

    // React to play/pause toggles from the mini-bar only when this screen is active
    final svc = TimerService.instance;
    if (_state == null) {
      if (kDebugMode) {
        debugPrint('POMODORO: ignoring update, state is null');
      }
      return;
    }

    // Only apply if the service refers to this task
    if (svc.activeTaskName != widget.todo.text) {
      if (kDebugMode) {
        debugPrint(
          'POMODORO: ignoring update for different task (${svc.activeTaskName} vs ${widget.todo.text})',
        );
      }
      return;
    }

    // If running changed, start/stop our local ticker accordingly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shouldBeRunning = svc.isRunning;
      final isCurrentlyRunning = _state!.timerState == 'running';
      if (shouldBeRunning && !isCurrentlyRunning) {
        setState(() {
          _state = TaskTimerState(
            taskId: _state!.taskId,
            timerState: 'running',
            currentMode: _state!.currentMode,
            timeRemaining: svc.timeRemaining,
            focusDuration: _state!.focusDuration,
            breakDuration: _state!.breakDuration,
            currentCycle: _state!.currentCycle,
            totalCycles: _state!.totalCycles,
          );
        });
        _startTicker();
      } else if (!shouldBeRunning && isCurrentlyRunning) {
        if (kDebugMode) {
          debugPrint(
            'POMODORO: onServiceUpdate - service requested pause for this task',
          );
          debugPrintStack(
            label: 'POMODORO: stack when service requested pause',
          );
        }
        setState(() {
          _state = TaskTimerState(
            taskId: _state!.taskId,
            timerState: 'paused',
            currentMode: _state!.currentMode,
            timeRemaining: svc.timeRemaining,
            focusDuration: _state!.focusDuration,
            breakDuration: _state!.breakDuration,
            currentCycle: _state!.currentCycle,
            totalCycles: _state!.totalCycles,
          );
        });
        _ticker?.cancel();
      }
    });
  }

  Future<void> _loadState() async {
    final s = await _store.load(widget.todo.id.toString());
    if (kDebugMode) {
      debugPrint("Loaded state: ${s?.toJson()}");
    }
    setState(() {
      _state =
          s ??
          TaskTimerState(
            taskId: widget.todo.id.toString(),
            timerState: 'paused',
            currentMode: 'focus',
            timeRemaining: 25 * 60,
            focusDuration: 25 * 60,
            breakDuration: 5 * 60,
            totalCycles: 4,
          );
      // Set up suppression window in post-frame callback to avoid race conditions
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // briefly suppress reacting to service updates to avoid races with the
        // minibar's ticker
        _suppressServiceReactions = true;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            _suppressServiceReactions = false;
            if (kDebugMode) {
              debugPrint(
                'POMODORO: suppression window ended, will react to service updates',
              );
            }
          }
        });
      });
      _focusController = TextEditingController(
        text: (_state!.focusDuration! ~/ 60).toString(),
      );
      // Recalculate cycles live as the user edits focus duration
      _focusController.addListener(() {
        if (!mounted) return;
        // Update state focusDuration preview immediately
        final intVal =
            int.tryParse(_focusController.text.trim()) ??
            (_state!.focusDuration! ~/ 60);
        setState(() {
          _state = TaskTimerState(
            taskId: _state!.taskId,
            timerState: _state!.timerState,
            currentMode: _state!.currentMode,
            timeRemaining: _state!.timeRemaining,
            focusDuration: intVal * 60,
            breakDuration: _state!.breakDuration,
            currentCycle: _state!.currentCycle,
            totalCycles: _calculateCycles(intVal),
          );
          _cyclesController.text = _state!.totalCycles.toString();
        });
      });
      _breakController = TextEditingController(
        text: (_state!.breakDuration! ~/ 60).toString(),
      );
      _cyclesController = TextEditingController(
        text: _state!.totalCycles.toString(),
      );
      // If TimerService has an active timer for this task, prefer its remaining
      final svc = TimerService.instance;
      // Prefer central service state for this task when available
      if (svc.activeTaskName == widget.todo.text) {
        if (kDebugMode) {
          debugPrint(
            'POMODORO: preferring TimerService state for this task during load, isRunning=${svc.isRunning}',
          );
        }
        // Get the total focused time from the service, which is the most up-to-date
        final serviceFocusedTime =
            svc.getFocusedTime(widget.todo.text) ?? widget.todo.focusedTime;

        // The session-specific focused time is the total from the service
        // minus what's already stored in the database for the todo. This
        // correctly accounts for time tracked in the mini-bar.
        final sessionFocusedTime = max(
          0,
          serviceFocusedTime - widget.todo.focusedTime,
        );

        // pull remaining and running state from the central service
        _state = TaskTimerState(
          taskId: _state!.taskId,
          timerState: svc.isRunning ? 'running' : 'paused',
          currentMode: svc.currentMode,
          timeRemaining: svc.timeRemaining,
          focusDuration: _state!.focusDuration,
          breakDuration: _state!.breakDuration,
          currentCycle: _state!.currentCycle,
          totalCycles: _state!.totalCycles,
          // Use the calculated session time to sync with the mini-bar's progress
          lastFocusedTime: sessionFocusedTime,
        );
        // If the timer was running in minibar, start it here too
        if (svc.isRunning) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _startTicker();
          });
        }

        // Also check for overdue state immediately upon load
        final totalFocusedTime =
            svc.getFocusedTime(widget.todo.text) ?? widget.todo.focusedTime;
        final plannedSeconds =
            (widget.todo.durationHours * 3600) +
            (widget.todo.durationMinutes * 60);
        if (plannedSeconds > 0 &&
            totalFocusedTime >= plannedSeconds &&
            !_overduePromptShown) {
          _showOverduePrompt();
        }
      }
    });
  }

  void _startTicker() {
    if (kDebugMode) {
      debugPrint("Starting ticker...");
    }
    if (kDebugMode) {
      debugPrint(
        'POMODORO: _startTicker state before update. lastFocusedTime=${_state?.lastFocusedTime}',
      );
    }
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    // Initialize the focused time cache right away to prevent race conditions
    // if the user closes the sheet before the first tick.
    if (_state?.currentMode == 'focus') {
      TimerService.instance.setFocusedTime(
        widget.todo.text,
        widget.todo.focusedTime + (_state?.lastFocusedTime ?? 0),
      );
    }
    // Update service state but preserve running state during transitions
    setState(() {
      _state = TaskTimerState(
        taskId: _state!.taskId,
        timerState: 'running',
        currentMode: _state!.currentMode,
        timeRemaining: _state!.timeRemaining,
        focusDuration: _state!.focusDuration,
        breakDuration: _state!.breakDuration,
        currentCycle: _state!.currentCycle,
        totalCycles: _state!.totalCycles,
        lastFocusedTime: _state!.lastFocusedTime, // Preserve last focused time
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kDebugMode && mounted) {
        debugPrint(
          'POMODORO: _startTicker state after update. lastFocusedTime=${_state?.lastFocusedTime}',
        );
      }
    });

    TimerService.instance.update(
      taskName: widget.todo.text,
      running: true,
      remaining: _state?.timeRemaining ?? (_state?.focusDuration ?? 1500),
      active: false, // full screen open
      plannedDuration:
          (widget.todo.durationHours * 3600) +
          (widget.todo.durationMinutes * 60),
      // Provide planned duration to service
      mode: _state?.currentMode,
    );
  }

  void _stopTicker() {
    if (kDebugMode) {
      debugPrint("Stopping ticker.");
    }
    _ticker?.cancel();
    _ticker = null;
    TimerService.instance.update(
      running: false,
      remaining: _state?.timeRemaining,
      active: false,
      mode: _state?.currentMode,
    );
    if (_state != null) {
      final totalFocusedTime =
          widget.todo.focusedTime + _state!.lastFocusedTime;
      widget.api.updateFocusTime(widget.todo.id, totalFocusedTime);
    }
  }

  Future<void> _tick() async {
    if (_state == null) return;
    if (kDebugMode) {
      debugPrint(
        'POMODORO: _tick called. state.lastFocusedTime=${_state?.lastFocusedTime}',
      );
    }

    if ((_state!.timeRemaining ?? 0) > 0) {
      final isFocus = _state!.currentMode == 'focus';
      final newLastFocused = isFocus
          ? _state!.lastFocusedTime + 1
          : _state!.lastFocusedTime;

      setState(() {
        _state = TaskTimerState(
          taskId: _state!.taskId,
          timerState: _state!.timerState,
          currentMode: _state!.currentMode,
          timeRemaining: (_state!.timeRemaining ?? 0) - 1,
          focusDuration: _state!.focusDuration,
          breakDuration: _state!.breakDuration,
          currentCycle: _state!.currentCycle,
          totalCycles: _state!.totalCycles,
          lastFocusedTime: newLastFocused,
        );
      });
      final rem = _state!.timeRemaining ?? 0;
      if (kDebugMode) {
        debugPrint('Tick: ${rem}s remaining');
      }
      // save every 10s but update the mini-bar every tick for smooth reflection
      if (kDebugMode) {
        debugPrint('Saving state to local store tick block check');
      }
      // If we are in focus mode, increment the task's focused time and sync
      if (isFocus) {
        // The total focused time is the initial time from the todo object
        // plus the time accumulated in this specific pomodoro session.
        final totalFocusedTime = widget.todo.focusedTime + newLastFocused;
        final plannedSeconds =
            (widget.todo.durationHours * 3600) +
            (widget.todo.durationMinutes * 60);

        // Check for overdue condition before updating UI
        if (plannedSeconds > 0 &&
            totalFocusedTime >= plannedSeconds &&
            !_overduePromptShown) {
          _showOverduePrompt();
          return; // Stop further processing in this tick
        }
        // update TimerService cache immediately for UI sync
        TimerService.instance.setFocusedTime(
          widget.todo.text,
          totalFocusedTime,
        );

        // persist every 10s to store and occasionally to server
        if (rem % 10 == 0) {
          await _store.save(widget.todo.id.toString(), _state!);
          try {
            // Send the new *total* focused time to the server.
            await widget.api.updateFocusTime(widget.todo.id, totalFocusedTime);
          } catch (_) {
            // ignore network errors; local store keeps the truth
          }
        }
      } else {
        // for break mode, just save state periodically
        if (rem % 10 == 0) {
          await _store.save(widget.todo.id.toString(), _state!);
        }
      }

      TimerService.instance.update(
        taskName: widget.todo.text,
        running: _state!.timerState == 'running',
        remaining: _state!.timeRemaining,
        mode: _state!.currentMode,
      );
      return;
    }

    _ticker?.cancel();
    if (kDebugMode) {
      debugPrint(
        'DEBUG: Timer reached 0. Current mode: ${_state!.currentMode}',
      );
    }

    if (_state!.currentMode == 'focus') {
      final newCycle = _state!.currentCycle + 1;
      setState(() {
        _state = TaskTimerState(
          taskId: _state!.taskId,
          timerState: 'running',
          currentMode: 'break',
          timeRemaining: _state!.breakDuration,
          focusDuration: _state!.focusDuration,
          breakDuration: _state!.breakDuration,
          currentCycle: newCycle,
          totalCycles: _state!.totalCycles,
        );
      });

      widget.notificationService.showNotification(
        title: 'Focus session ended',
        body: 'Time for a break!',
      );
      widget.notificationService.playSound(
        'assets/sounds/Break timer start.wav',
      );

      if (newCycle >= (_state!.totalCycles ?? 0)) {
        if (kDebugMode) {
          debugPrint('All cycles completed.');
        }
        widget.notificationService.showNotification(
          title: 'All Cycles Completed!',
          body: 'Great job focusing on "${widget.todo.text}".',
        );
        _showCompletionModal();
        _stopTicker();
        TimerService.instance.clear();
        return;
      }
    } else {
      setState(() {
        _state = TaskTimerState(
          taskId: _state!.taskId,
          timerState: 'running',
          currentMode: 'focus',
          timeRemaining: _state!.focusDuration,
          focusDuration: _state!.focusDuration,
          breakDuration: _state!.breakDuration,
          currentCycle: _state!.currentCycle,
          totalCycles: _state!.totalCycles,
        );
      });

      widget.notificationService.showNotification(
        title: 'Break ended',
        body: 'Time to focus!',
      );
      widget.notificationService.playSound(
        'assets/sounds/Focus timer start.wav',
      );
    }

    if (kDebugMode) {
      debugPrint(
        'DEBUG: New state: Mode=${_state!.currentMode}, Time=${_state!.timeRemaining}',
      );
    }
    await _store.save(widget.todo.id.toString(), _state!);

    // update mini-bar after mode switch
    TimerService.instance.update(
      taskName: widget.todo.text,
      running: _state!.timerState == 'running',
      remaining: _state!.timeRemaining,
      active: true,
      mode: _state!.currentMode,
    );

    _startTicker();
  }

  Future<void> _showCompletionModal() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All cycles completed!'),
        content: const Text('You have finished all cycles for this task.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOverduePrompt() async {
    if (kDebugMode) {
      debugPrint('POMODORO: Task is now overdue. Showing prompt.');
    }
    _overduePromptShown = true; // Prevent showing it again
    _stopTicker(); // Pause the timer

    widget.notificationService.showNotification(
      title: 'Task Overdue',
      body: 'Planned time for "${widget.todo.text}" is complete.',
    );
    // Corrected filename (no spaces) and wrapped in a try-catch
    try {
      widget.notificationService.playSound(
        'assets/sounds/progress_bar_full.wav',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to play sound: $e');
      }
    }

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false, // User must make a choice
      builder: (ctx) => AlertDialog(
        title: Text('"${widget.todo.text}" Overdue'),
        content: const Text(
          'Planned time is complete. Mark task as done or continue working?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('continue'),
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop('complete'),
            child: const Text('Mark Complete'),
          ),
        ],
      ),
    );

    if (result == 'complete') {
      // Use the callback to let the parent handle the API call and UI refresh
      await widget.onTaskCompleted();
      TimerService.instance.clear();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      if (kDebugMode) {
        debugPrint('POMODORO: User chose to continue overdue task.');
      }
    }
  }

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int _calculateCycles(int focusMinutes) {
    final taskMinutes =
        (widget.todo.durationHours * 60) + widget.todo.durationMinutes;
    final effectiveFocus = focusMinutes > 0 ? focusMinutes : 25;
    final raw = taskMinutes ~/ effectiveFocus;
    return raw > 0 ? raw : 1;
  }

  Future<void> _applyAutoCalculateCyclesIfNeeded({bool force = false}) async {
    final curText = _cyclesController.text.trim();
    final curVal = int.tryParse(curText) ?? 0;
    if (kDebugMode) {
      debugPrint(
        'Auto-calc: current cycles input="$curText" parsed=$curVal force=$force',
      );
    }
    if (!force && curVal > 0) {
      if (kDebugMode) {
        debugPrint(
          'Auto-calc: user provided cycles, skipping auto-calculation.',
        );
      }
      return; // user provided a manual value, respect it
    }

    final focusMinutes =
        int.tryParse(_focusController.text.trim()) ??
        ((_state?.focusDuration ?? 1500) ~/ 60);
    final calculated = _calculateCycles(focusMinutes);
    if (kDebugMode) {
      debugPrint(
        'Auto-calc: taskMinutes=${(widget.todo.durationHours * 60) + widget.todo.durationMinutes} focusMinutes=$focusMinutes calculated=$calculated',
      );
    }

    setState(() {
      _cyclesController.text = calculated.toString();
      _state = TaskTimerState(
        taskId: _state!.taskId,
        timerState: _state!.timerState,
        currentMode: _state!.currentMode,
        timeRemaining: _state!.timeRemaining,
        focusDuration: _state!.focusDuration,
        breakDuration: _state!.breakDuration,
        currentCycle: _state!.currentCycle,
        totalCycles: calculated,
      );
    });
    await _store.save(widget.todo.id.toString(), _state!);
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    if (s == null) return const Center(child: CircularProgressIndicator());

    final isRunning = s.timerState == 'running';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      onPressed: () {
                        // First pause the timer if it's running
                        if (_state?.timerState == 'running') {
                          _stopTicker();
                        }

                        // Reset timer to initial state
                        setState(() {
                          _state = TaskTimerState(
                            taskId: widget.todo.id.toString(),
                            timerState: 'paused',
                            currentMode: 'focus',
                            timeRemaining: 25 * 60, // Default 25 minutes
                            focusDuration: 25 * 60,
                            breakDuration: 5 * 60,
                            totalCycles: 4,
                          );
                        });

                        // Clear both the service state and mini-bar before closing
                        TimerService.instance.clear();
                        // Persist the reset state so reopening shows initial UI
                        _store.save(widget.todo.id.toString(), _state!);

                        // Close the sheet
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
              // Increased space between title and task box for clearer hierarchy
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
              // Progress bar for overall task completion
              Builder(
                builder: (ctx) {
                  final plannedSeconds =
                      (widget.todo.durationHours * 3600) +
                      (widget.todo.durationMinutes * 60);
                  final cached =
                      TimerService.instance.getFocusedTime(widget.todo.text) ??
                      widget.todo.focusedTime;
                  return Padding(
                    // Slightly reduced top padding so the progress bar sits
                    // a bit closer to the content above and ultimately
                    // closer to the timer when the large spacer is reduced.
                    padding: const EdgeInsets.only(top: 48.0, bottom: 8.0),
                    child: SizedBox(
                      // Wrapper to control overall space. Height increased
                      // to comfortably contain a thicker progress bar.
                      height: 34,
                      child: ProgressBar(
                        focusedSeconds: cached,
                        plannedSeconds: plannedSeconds,
                        barHeight: 28.0, // Thicker progress bar
                      ),
                    ),
                  );
                },
              ),
              // Reduced vertical breathing room so the progress bar,
              // cycle counters and timer are visually closer together.
              const SizedBox(height: 12),
            ],
          ),
          // Settings row (Focus / Break / Cycles)
          // Show full interactive settings only in the initial pre-start state.
          if (s.timerState == 'paused' &&
              s.timeRemaining == s.focusDuration) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Column 1: Work Duration (box, long yellow line, bottom label)
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
                        border: Border.all(
                          color: Colors.grey.shade700,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: TextField(
                        controller: _focusController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 18.0,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        onChanged: (value) async {
                          final intValue = int.tryParse(value) ?? 0;
                          setState(() {
                            _state = TaskTimerState(
                              taskId: s.taskId,
                              timerState: s.timerState,
                              currentMode: s.currentMode,
                              timeRemaining:
                                  s.currentMode == 'focus' && intValue > 0
                                  ? intValue * 60
                                  : s.timeRemaining,
                              focusDuration: intValue > 0
                                  ? intValue * 60
                                  : s.focusDuration,
                              breakDuration: s.breakDuration,
                              currentCycle: s.currentCycle,
                              totalCycles: s.totalCycles,
                            );
                            _store.save(widget.todo.id.toString(), _state!);
                          });
                          await _applyAutoCalculateCyclesIfNeeded();
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 2,
                      height: 56,
                      color: AppColors.brightYellow,
                    ),
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

                // Column 2: Break Time (label above, long yellow line, box)
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
                    Container(
                      width: 2,
                      height: 56,
                      color: AppColors.brightYellow,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 88,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: Colors.grey.shade700,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: TextField(
                        controller: _breakController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 18.0,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          final intValue = int.tryParse(value) ?? 0;
                          setState(() {
                            _state = TaskTimerState(
                              taskId: s.taskId,
                              timerState: s.timerState,
                              currentMode: s.currentMode,
                              timeRemaining:
                                  s.currentMode == 'break' && intValue > 0
                                  ? intValue * 60
                                  : s.timeRemaining,
                              focusDuration: s.focusDuration,
                              breakDuration: intValue > 0
                                  ? intValue * 60
                                  : s.breakDuration,
                              currentCycle: s.currentCycle,
                              totalCycles: s.totalCycles,
                            );
                            _store.save(widget.todo.id.toString(), _state!);
                          });
                        },
                      ),
                    ),
                  ],
                ),

                // Column 3: Cycles (box, long yellow line, bottom label)
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
                        border: Border.all(
                          color: Colors.grey.shade700,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: TextField(
                        controller: _cyclesController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 18.0,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          final intValue = int.tryParse(value) ?? 0;
                          if (intValue <= 0) return;
                          setState(() {
                            _state = TaskTimerState(
                              taskId: s.taskId,
                              timerState: s.timerState,
                              currentMode: s.currentMode,
                              timeRemaining: s.timeRemaining,
                              focusDuration: s.focusDuration,
                              breakDuration: s.breakDuration,
                              currentCycle: s.currentCycle,
                              totalCycles: intValue,
                            );
                            _store.save(widget.todo.id.toString(), _state!);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 2,
                      height: 56,
                      color: AppColors.brightYellow,
                    ),
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
            // Space between settings and the main timer
            const SizedBox(height: 24),
          ] else ...[
            // Compact settings display after timer has started
            Text(
              '${(s.focusDuration! ~/ 60)} / ${(s.breakDuration! ~/ 60)} / ${s.totalCycles}',
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            // Cycle counter (no icon in any state)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${s.currentCycle} / ${s.totalCycles}',
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
            // Make the timer the dominant visual element
            Expanded(
              flex: 5,
              child: Center(
                child: IntrinsicWidth(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            (s.timerState == 'running' ||
                                s.timerState == 'paused')
                            ? (s.currentMode == 'focus'
                                  ? Colors.redAccent
                                  : Colors.greenAccent)
                            : Colors.transparent,
                        width: 6.0, // make border slightly thicker
                      ),
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    child: Container(
                      // Give the timer box a slightly larger footprint
                      // and uniform padding so digits sit away from all edges.
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        _format(s.timeRemaining!),
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

          // Buttons row
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Left secondary circular outlined button (Reset) with yellow ring
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
                          onPressed: () async {
                            if (kDebugMode) {
                              debugPrint("Resetting current session timer.");
                            }
                            _ticker
                                ?.cancel(); // Stop timer without saving progress

                            // Reset the focused time in the service cache to its pre-session value
                            TimerService.instance.setFocusedTime(
                              widget.todo.text,
                              widget.todo.focusedTime,
                            );

                            setState(() {
                              _state = TaskTimerState(
                                taskId: s.taskId,
                                timerState: 'paused',
                                currentMode: s.currentMode,
                                timeRemaining: s.currentMode == 'focus'
                                    ? s.focusDuration
                                    : s.breakDuration,
                                focusDuration: s.focusDuration,
                                breakDuration: s.breakDuration,
                                currentCycle: s.currentCycle,
                                totalCycles: s.totalCycles,
                                lastFocusedTime: 0, // Discard session progress
                              );
                            });
                            await _store.save(
                              widget.todo.id.toString(),
                              _state!,
                            );
                            TimerService.instance.update(
                              taskName: widget.todo.text,
                              running: false,
                              remaining: _state?.timeRemaining,
                              mode: _state?.currentMode,
                              active: false,
                            );
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

                  // Center primary circular action
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: FloatingActionButton(
                          backgroundColor: AppColors.brightYellow,
                          onPressed: () async {
                            if (isRunning) {
                              if (kDebugMode) {
                                debugPrint("Pausing timer.");
                                debugPrintStack(
                                  label:
                                      'POMODORO: stack when user tapped pause',
                                );
                              }
                              setState(() {
                                _state = TaskTimerState(
                                  taskId: s.taskId,
                                  timerState: 'paused',
                                  currentMode: s.currentMode,
                                  timeRemaining: s.timeRemaining,
                                  focusDuration: s.focusDuration,
                                  breakDuration: s.breakDuration,
                                  currentCycle: s.currentCycle,
                                  totalCycles: s.totalCycles,
                                  lastFocusedTime: s.lastFocusedTime,
                                );
                                _stopTicker();
                                _store.save(widget.todo.id.toString(), _state!);
                              });
                            } else {
                              await _applyAutoCalculateCyclesIfNeeded(
                                force: true,
                              );
                              if (kDebugMode) {
                                debugPrint("Starting timer.");
                                debugPrintStack(
                                  label:
                                      'POMODORO: stack when user tapped start',
                                );
                              }
                              setState(() {
                                _state = TaskTimerState(
                                  taskId: s.taskId,
                                  timerState: 'running',
                                  currentMode: s.currentMode,
                                  timeRemaining: s.timeRemaining,
                                  focusDuration: s.focusDuration,
                                  breakDuration: s.breakDuration,
                                  currentCycle: s.currentCycle,
                                  totalCycles: s.totalCycles,
                                  lastFocusedTime: s.lastFocusedTime,
                                );
                                _startTicker();
                                _store.save(widget.todo.id.toString(), _state!);
                              });
                            }
                          },
                          child: Icon(
                            isRunning
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isRunning ? 'Pause' : 'Start',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4), // Space for button label
                    ],
                  ),

                  // Right secondary circular outlined button (Skip)
                  // Right secondary circular outlined button (Skip) with yellow ring
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
                          onPressed: () async {
                            if (kDebugMode) {
                              debugPrint("Skipping to next phase.");
                            }
                            final bool isFocus = s.currentMode == 'focus';
                            // Persist progress from the focus session being skipped
                            if (isFocus) {
                              final totalFocusedTime =
                                  widget.todo.focusedTime + s.lastFocusedTime;
                              await widget.api.updateFocusTime(
                                widget.todo.id,
                                totalFocusedTime,
                              );
                              TimerService.instance.setFocusedTime(
                                widget.todo.text,
                                totalFocusedTime,
                              );
                            }
                            setState(() {
                              _state = TaskTimerState(
                                taskId: s.taskId,
                                timerState: 'running',
                                currentMode: isFocus ? 'break' : 'focus',
                                timeRemaining: isFocus
                                    ? s.breakDuration
                                    : s.focusDuration,
                                focusDuration: s.focusDuration,
                                breakDuration: s.breakDuration,
                                currentCycle: isFocus
                                    ? s.currentCycle + 1
                                    : s.currentCycle,
                                totalCycles: s.totalCycles,
                                lastFocusedTime: s.lastFocusedTime,
                              );
                              _startTicker();
                              _store.save(widget.todo.id.toString(), _state!);
                            });
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
          ),
        ],
      ),
    );
  }
}
