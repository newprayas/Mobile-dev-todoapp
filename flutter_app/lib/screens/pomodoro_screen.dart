import 'dart:async';
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

class PomodoroScreen extends StatefulWidget {
  final ApiService api;
  final Todo todo;
  final NotificationService notificationService;
  final bool asSheet;

  const PomodoroScreen({
    required this.api,
    required this.todo,
    required this.notificationService,
    this.asSheet = false,
    super.key,
  });

  static Future<void> showAsBottomSheet(
    BuildContext context,
    ApiService api,
    Todo todo,
    NotificationService notificationService,
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
        if (kDebugMode)
          debugPrint('POMODORO: minibar suppressed because service cleared');
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
          child: WillPopScope(
            onWillPop: () async {
              updateMinibar(); // Handle back button press
              return true;
            },
            child: GestureDetector(
              onTap: () {},
              child: PomodoroScreen(
                api: api,
                todo: todo,
                notificationService: notificationService,
                asSheet: true,
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
      if (kDebugMode)
        debugPrint(
          'POMODORO: ignoring service update due to suppression window',
        );
      return;
    }

    // React to play/pause toggles from the mini-bar only when this screen is active
    final svc = TimerService.instance;
    if (_state == null) {
      if (kDebugMode) debugPrint('POMODORO: ignoring update, state is null');
      return;
    }

    // Only apply if the service refers to this task
    if (svc.activeTaskName != widget.todo.text) {
      if (kDebugMode)
        debugPrint(
          'POMODORO: ignoring update for different task (${svc.activeTaskName} vs ${widget.todo.text})',
        );
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
    if (kDebugMode) debugPrint("Loaded state: ${s?.toJson()}");
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
        // briefly suppress reacting to service updates to avoid races with the minibar's ticker
        _suppressServiceReactions = true;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            _suppressServiceReactions = false;
            if (kDebugMode)
              debugPrint(
                'POMODORO: suppression window ended, will react to service updates',
              );
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
        if (kDebugMode)
          debugPrint(
            'POMODORO: preferring TimerService state for this task during load, isRunning=${svc.isRunning}',
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
        );
        // If the timer was running in minibar, start it here too
        if (svc.isRunning) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _startTicker();
          });
        }
      }
    });
  }

  void _startTicker() {
    if (kDebugMode) debugPrint("Starting ticker...");
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

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
      );
    });

    TimerService.instance.update(
      taskName: widget.todo.text,
      running: true,
      remaining: _state?.timeRemaining ?? (_state?.focusDuration ?? 1500),
      active: false, // full screen open
      mode: _state?.currentMode,
    );
  }

  void _stopTicker() {
    if (kDebugMode) debugPrint("Stopping ticker.");
    _ticker?.cancel();
    _ticker = null;
    TimerService.instance.update(
      running: false,
      remaining: _state?.timeRemaining,
      active: false,
      mode: _state?.currentMode,
    );
  }

  Future<void> _tick() async {
    if (_state == null) return;

    if ((_state!.timeRemaining ?? 0) > 0) {
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
        );
      });
      final rem = _state!.timeRemaining ?? 0;
      if (kDebugMode) debugPrint('Tick: ${rem}s remaining');
      // save every 10s but update the mini-bar every tick for smooth reflection
      if (kDebugMode)
        debugPrint('Saving state to local store tick block check');
      // If we are in focus mode, increment the task's focused time and sync
      if (_state!.currentMode == 'focus') {
        // update lastFocusedTime in our stored state (lastFocusedTime is non-nullable)
        final newLastFocused = _state!.lastFocusedTime + 1;
        setState(() {
          _state = TaskTimerState(
            taskId: _state!.taskId,
            timerState: _state!.timerState,
            currentMode: _state!.currentMode,
            timeRemaining: _state!.timeRemaining,
            focusDuration: _state!.focusDuration,
            breakDuration: _state!.breakDuration,
            currentCycle: _state!.currentCycle,
            totalCycles: _state!.totalCycles,
            // preserve lastFocusedTime
            lastFocusedTime: newLastFocused,
          );
        });

        // update TimerService cache immediately for UI sync
        TimerService.instance.setFocusedTime(widget.todo.text, newLastFocused);

        // persist every 10s to store and occasionally to server
        if (rem % 10 == 0) {
          await _store.save(widget.todo.id.toString(), _state!);
          try {
            await widget.api.updateFocusTime(widget.todo.id, newLastFocused);
          } catch (_) {
            // ignore network errors; local store keeps the truth
          }
        }
      } else {
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
        if (kDebugMode) debugPrint('All cycles completed.');
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
                    padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                    child: SizedBox(
                      height: 18,
                      child: ProgressBar(
                        focusedSeconds: cached,
                        plannedSeconds: plannedSeconds,
                        isFocusMode:
                            (_state?.currentMode ??
                                TimerService.instance.currentMode) ==
                            'focus',
                      ),
                    ),
                  );
                },
              ),
              // More vertical breathing room between task box and settings
              const SizedBox(height: 56),
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
                        width: 4.0,
                      ),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Padding(
                      // Comfortable padding so digits have clear breathing room
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 28.0,
                      ),
                      child: Transform.translate(
                        offset: const Offset(0, -4),
                        child: Text(
                          _format(s.timeRemaining!),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.oswald(
                            fontSize: 140.0,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -6.0,
                            height: 0.8,
                            color: Colors.white,
                          ),
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
                          onPressed: () {
                            if (kDebugMode) debugPrint("Resetting timer.");
                            setState(() {
                              _state = TaskTimerState(
                                taskId: s.taskId,
                                timerState: 'paused',
                                currentMode: 'focus',
                                timeRemaining: s.focusDuration,
                                focusDuration: s.focusDuration,
                                breakDuration: s.breakDuration,
                                currentCycle: 0,
                                totalCycles: s.totalCycles,
                              );
                              _stopTicker();
                              _store.save(widget.todo.id.toString(), _state!);
                            });
                            // clear mini-bar
                            TimerService.instance.clear();
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
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                          onPressed: () {
                            if (kDebugMode)
                              debugPrint("Skipping to next phase.");
                            final bool isFocus = s.currentMode == 'focus';
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

  // ...existing code... (time settings were removed in the minimalist redesign)
}
