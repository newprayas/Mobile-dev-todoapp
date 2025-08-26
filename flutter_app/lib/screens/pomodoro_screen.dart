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

    // Save current state when screen is disposed to preserve state between task switches
    if (_state != null) {
      _store.save(widget.todo.id.toString(), _state!);

      // FIX: Get current service focused time instead of using lastFocusedTime from state
      // This prevents progress bar reset when transitioning to minibar
      final currentServiceFocusedTime = TimerService.instance.getFocusedTime(
        widget.todo.text,
      );

      if (_state!.currentMode == 'focus' && currentServiceFocusedTime != null) {
        // Use service's current focused time as it has the latest cumulative value
        WidgetsBinding.instance.addPostFrameCallback((_) {
          TimerService.instance.setFocusedTime(
            widget.todo.text,
            currentServiceFocusedTime,
          );
        });

        if (kDebugMode) {
          debugPrint(
            'POMODORO: disposing, preserved focused time for ${widget.todo.text}: ${currentServiceFocusedTime}s from service',
          );
        }
      }
    }

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
            completedSessions: _state!.completedSessions,
            isProgressBarFull: _state!.isProgressBarFull,
            allSessionsComplete: _state!.allSessionsComplete,
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
            completedSessions: _state!.completedSessions,
            isProgressBarFull: _state!.isProgressBarFull,
            allSessionsComplete: _state!.allSessionsComplete,
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

    // Check if this is a reverted completed task - if so, reset to setup screen
    final wasCompleted = widget.todo.completed;
    final hasStoredState = s != null;

    if (kDebugMode) {
      debugPrint(
        "LOAD STATE: wasCompleted=$wasCompleted, hasStoredState=$hasStoredState",
      );
    }

    // Validate stored state for corruption or invalid values
    bool hasCorruptedState = false;
    if (s != null) {
      // Check for corrupted durations (extremely large values)
      if ((s.focusDuration ?? 0) > 24 * 3600 || // More than 24 hours
          (s.breakDuration ?? 0) > 24 * 3600 ||
          (s.timeRemaining ?? 0) > 24 * 3600 ||
          (s.focusDuration ?? 0) < 60 || // Less than 1 minute
          (s.breakDuration ?? 0) < 60) {
        hasCorruptedState = true;
        if (kDebugMode) {
          debugPrint(
            "LOAD STATE: Detected corrupted state with invalid durations",
          );
        }
      }
    }

    // If task was recently reverted from completed, force reset to setup screen
    bool shouldResetToSetup = false;
    if (!widget.todo.completed && s != null) {
      // Check if this task was previously completed by looking at stored metadata
      shouldResetToSetup = s.allSessionsComplete || s.isProgressBarFull;
    }

    // For NEW tasks (no focused time), always show setup screen
    // Only treat as new task if there's truly no progress anywhere
    bool isNewTask =
        widget.todo.focusedTime == 0 &&
        (s == null || s.lastFocusedTime == 0) &&
        TimerService.instance.activeTaskName != widget.todo.text &&
        (s == null ||
            s.timerState == 'idle' ||
            s.timerState == 'paused'); // Allow setup for new/idle tasks

    // SPECIAL CASE: For overdue tasks where user chose to continue and no saved state exists,
    // treat as new task to force setup screen
    // Treat an overdue task that the user opted to "continue" as a fresh setup
    // regardless of whether a stored state exists. Previously this only triggered
    // when there was no stored state (s == null), which caused the UI to reopen
    // directly in the running view instead of the setup screen until the user
    // manually pressed reset. This fixes the reported issue: the setup page
    // should appear immediately after continuing an overdue task.
    bool isOverdueTaskRestart =
        TimerService.instance.hasUserContinuedOverdue(widget.todo.text) &&
        TimerService.instance.activeTaskName != widget.todo.text;

    // Check if this task has become overdue but user hasn't made a choice yet
    // This happens when: task exceeded planned duration, TimerService called clear(),
    // but user hasn't clicked "Continue Working" or "Mark Complete" yet
    bool taskJustBecameOverdue =
        widget.todo.focusedTime > 0 && // Task has some progress
        TimerService.instance.activeTaskName !=
            widget.todo.text && // Service is cleared
        !TimerService.instance.hasUserContinuedOverdue(
          widget.todo.text,
        ) && // User hasn't chosen to continue
        !TimerService.instance.hasOverduePromptBeenShown(
          widget.todo.text,
        ); // Prompt hasn't been shown yet

    // Force setup ONLY when the user previously chose to continue working on an overdue task.
    // Do NOT force setup for tasks that just became overdue - those should show the overdue prompt
    bool forceSetupForContinuedOverdue = TimerService.instance
        .hasUserContinuedOverdue(widget.todo.text);

    if (kDebugMode) {
      debugPrint(
        "LOAD STATE DEBUG: focusedTime=${widget.todo.focusedTime}, "
        "hasStoredState=${s != null}, "
        "isNewTask=$isNewTask, "
        "isOverdueTaskRestart=$isOverdueTaskRestart, "
        "taskJustBecameOverdue=$taskJustBecameOverdue, "
        "hasUserContinuedOverdue=${TimerService.instance.hasUserContinuedOverdue(widget.todo.text)}",
      );
    }

    // Additional check: if there's no stored state and no service state, definitely show setup
    if (s == null && TimerService.instance.activeTaskName != widget.todo.text) {
      isNewTask = true;
      if (kDebugMode) {
        debugPrint(
          "LOAD STATE: No stored state and no active service state - treating as new task",
        );
      }
    }

    setState(() {
      if (shouldResetToSetup ||
          hasCorruptedState ||
          isNewTask ||
          isOverdueTaskRestart ||
          forceSetupForContinuedOverdue) {
        // Force reset to initial setup state
        if (kDebugMode) {
          String reason = shouldResetToSetup
              ? "reverted completed task"
              : hasCorruptedState
              ? "corrupted state detected"
              : isOverdueTaskRestart
              ? "overdue task restart after continue"
              : forceSetupForContinuedOverdue
              ? "user continued overdue - forcing setup"
              : "new task requiring setup";
          debugPrint("LOAD STATE: Resetting to setup screen - $reason");
        }

        // Calculate proper cycles based on task duration, not hardcoded 25 minutes
        final defaultFocusMinutes = 25;
        // Clamp default focus duration to planned task duration if smaller (avoid 25m session on 1m task)
        final plannedSecondsForClamp =
            (widget.todo.durationHours * 3600) +
            (widget.todo.durationMinutes * 60);
        final clampedFocusSeconds = plannedSecondsForClamp > 0
            ? (plannedSecondsForClamp < defaultFocusMinutes * 60
                  ? plannedSecondsForClamp
                  : defaultFocusMinutes * 60)
            : defaultFocusMinutes * 60;
        final calculatedCycles = _calculateCycles(clampedFocusSeconds ~/ 60);

        _state = TaskTimerState(
          taskId: widget.todo.id.toString(),
          timerState: 'idle', // Use 'idle' for setup screen
          currentMode: 'focus',
          timeRemaining: clampedFocusSeconds,
          focusDuration: clampedFocusSeconds,
          breakDuration: 5 * 60,
          totalCycles:
              calculatedCycles, // Use calculated cycles based on task duration
          completedSessions: 0,
          isProgressBarFull: false,
          allSessionsComplete: false,
          lastFocusedTime: 0, // Start fresh
        );
        if (kDebugMode) {
          debugPrint(
            "LOAD STATE: Created fresh setup state (clampedFocus=${clampedFocusSeconds}s planned=${plannedSecondsForClamp}s) with timerState='idle'",
          );
        }
      } else if (taskJustBecameOverdue) {
        // Task just became overdue - create a state that will trigger the overdue prompt
        if (kDebugMode) {
          debugPrint(
            "LOAD STATE: Task just became overdue - preparing to show overdue prompt",
          );
        }
        _state =
            s ??
            TaskTimerState(
              taskId: widget.todo.id.toString(),
              timerState: 'paused', // Use paused state to trigger overdue check
              currentMode: 'focus',
              timeRemaining: 0, // No time remaining since it's overdue
              focusDuration: 25 * 60,
              breakDuration: 5 * 60,
              totalCycles: _calculateCycles(
                25,
              ), // This is correct - calculating based on task duration
              completedSessions: 0,
              isProgressBarFull: false,
              allSessionsComplete: false,
              lastFocusedTime:
                  widget.todo.focusedTime, // Use actual focused time
            );

        // Trigger overdue prompt immediately in the next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_overduePromptShown) {
            final plannedSeconds =
                (widget.todo.durationHours * 3600) +
                (widget.todo.durationMinutes * 60);
            if (plannedSeconds > 0 &&
                widget.todo.focusedTime >= plannedSeconds &&
                !TimerService.instance.hasOverduePromptBeenShown(
                  widget.todo.text,
                )) {
              if (kDebugMode) {
                debugPrint(
                  "LOAD STATE: Triggering overdue prompt for task that just became overdue",
                );
              }
              _showOverduePrompt();
            }
          }
        });
      } else {
        _state =
            s ??
            TaskTimerState(
              taskId: widget.todo.id.toString(),
              timerState: 'idle', // Default to setup screen if no saved state
              currentMode: 'focus',
              timeRemaining: 25 * 60,
              focusDuration: 25 * 60,
              breakDuration: 5 * 60,
              totalCycles: _calculateCycles(25),
              completedSessions: 0,
              isProgressBarFull: false,
              allSessionsComplete: false,
              lastFocusedTime: 0,
            );
      }
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
          _state = _createUpdatedState(
            focusDuration: intVal * 60,
            totalCycles: _calculateCycles(intVal),
          );
          _cyclesController.text = _state!.totalCycles.toString();
        });

        // Save state immediately when user changes focus duration
        _store.save(widget.todo.id.toString(), _state!);
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
        // If task is an overdue task the user chose to continue earlier, always restore to setup when reopening
        final plannedSecondsForResume =
            (widget.todo.durationHours * 3600) +
            (widget.todo.durationMinutes * 60);
        final cachedFocused =
            svc.getFocusedTime(widget.todo.text) ?? widget.todo.focusedTime;
        final isContinuedOverdue =
            plannedSecondsForResume > 0 &&
            cachedFocused >= plannedSecondsForResume &&
            TimerService.instance.hasUserContinuedOverdue(widget.todo.text);
        if (isContinuedOverdue) {
          if (kDebugMode) {
            debugPrint(
              'POMODORO: Reopening continued overdue task -> forcing setup screen',
            );
          }
          setState(() {
            _state = TaskTimerState(
              taskId: widget.todo.id.toString(),
              timerState: 'idle',
              currentMode: 'focus',
              timeRemaining: (_state?.focusDuration) ?? 25 * 60,
              focusDuration: _state?.focusDuration ?? 25 * 60,
              breakDuration: _state?.breakDuration ?? 5 * 60,
              totalCycles:
                  _state?.totalCycles ??
                  _calculateCycles((_state?.focusDuration ?? 1500) ~/ 60),
              completedSessions: 0,
              isProgressBarFull: false,
              allSessionsComplete: false,
              lastFocusedTime: 0,
            );
          });
          return; // skip adopting running state
        }
        // Get the total focused time from the service, which is the most up-to-date
        final serviceFocusedTime =
            svc.getFocusedTime(widget.todo.text) ?? widget.todo.focusedTime;

        // CRITICAL FIX: When service has current task, calculate session time properly
        // The session time should be: service_total - todo_base_time
        final todoBaseFocusedTime = widget.todo.focusedTime;
        final currentSessionTime = serviceFocusedTime > todoBaseFocusedTime
            ? serviceFocusedTime - todoBaseFocusedTime
            : (_state!.lastFocusedTime > 0 ? _state!.lastFocusedTime : 0);

        if (kDebugMode) {
          debugPrint(
            'POMODORO: serviceFocusedTime=$serviceFocusedTime, todo.focusedTime=$todoBaseFocusedTime, calculated session time=$currentSessionTime',
          );
        }

        // pull remaining and running state from the central service
        // AND preserve the calculated session time to avoid progress reset
        _state = _createUpdatedState(
          timerState: svc.isRunning ? 'running' : 'paused',
          currentMode: svc.currentMode,
          timeRemaining: svc.timeRemaining,
          lastFocusedTime: currentSessionTime, // Use calculated session time
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

        if (kDebugMode) {
          debugPrint(
            "OVERDUE CHECK ON LOAD: task=${widget.todo.text}, "
            "totalFocused=$totalFocusedTime, planned=$plannedSeconds, "
            "isOverdue=${totalFocusedTime >= plannedSeconds}, "
            "promptShown=$_overduePromptShown, "
            "servicePromptShown=${TimerService.instance.hasOverduePromptBeenShown(widget.todo.text)}",
          );
        }

        if (plannedSeconds > 0 &&
            totalFocusedTime >= plannedSeconds &&
            !_overduePromptShown &&
            !TimerService.instance.hasOverduePromptBeenShown(
              widget.todo.text,
            )) {
          _showOverduePrompt();
        }
      } else if (svc.activeTaskName != null &&
          svc.activeTaskName != widget.todo.text) {
        // If there's an active timer for a different task, pause it when switching to this task
        if (kDebugMode) {
          debugPrint(
            'POMODORO: pausing timer for different task (${svc.activeTaskName}) when switching to ${widget.todo.text}',
          );
        }
        // Pause the previous task's timer and preserve its state
        svc.update(running: false);

        // Start current task in its previous state (running or paused based on stored state)
        if (_state != null) {
          final shouldStartRunning = _state!.timerState == 'running';
          if (kDebugMode) {
            debugPrint(
              'POMODORO: starting current task ${widget.todo.text} in ${shouldStartRunning ? 'running' : 'paused'} state after task switch',
            );
          }
          setState(() {
            _state = _createUpdatedState(
              timerState: shouldStartRunning ? 'running' : 'paused',
            );
          });

          // If the stored state was running, start the ticker for this task
          if (shouldStartRunning) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _startTicker();
            });
          }
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

    // DO NOT reset the focused time cache here - this causes progress bar reset!
    // The focused time should only be updated during ticks, not at start

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
        completedSessions: _state!.completedSessions,
        isProgressBarFull: _state!.isProgressBarFull,
        allSessionsComplete: _state!.allSessionsComplete,
      );
    });
    // Play focus start only when entering a fresh focus session (not resume) and mode is focus
    try {
      if (_state?.currentMode == 'focus' &&
          (_state?.timeRemaining == _state?.focusDuration)) {
        if (kDebugMode) debugPrint('SOUND: Focus timer start (fresh session).');
        widget.notificationService.showNotification(
          title: 'Focus Started',
          body: 'Stay on task: "${widget.todo.text}"',
        );
        widget.notificationService.playSound('sounds/Focus timer start.wav');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SOUND ERROR (focus start fresh): $e');
    }
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
      focusDuration: _state?.focusDuration ?? 1500,
      breakDuration: _state?.breakDuration ?? 300,
      setTotalCycles: _state?.totalCycles ?? 4,
      setCurrentCycle: _state?.currentCycle ?? 1,
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
      focusDuration: _state?.focusDuration,
      breakDuration: _state?.breakDuration,
      setTotalCycles: _state?.totalCycles,
      setCurrentCycle: _state?.currentCycle,
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
        _state = _createUpdatedState(
          timeRemaining: (_state!.timeRemaining ?? 0) - 1,
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
        // CRITICAL FIX: Calculate total focused time correctly during timer resumption
        // Get the current cached focused time from TimerService (which already includes previous sessions)
        final currentCachedTime =
            TimerService.instance.getFocusedTime(widget.todo.text) ??
            widget.todo.focusedTime;

        // If we're resuming (cached time > base time), add just 1 second to cached time
        // If we're starting fresh, calculate as base + session time
        final totalFocusedTime = currentCachedTime > widget.todo.focusedTime
            ? currentCachedTime +
                  1 // Resume: increment cached time
            : widget.todo.focusedTime +
                  newLastFocused; // Fresh start: base + session

        if (kDebugMode) {
          debugPrint(
            'TICK DEBUG: cachedTime=$currentCachedTime, baseTime=${widget.todo.focusedTime}, sessionTime=$newLastFocused, totalTime=$totalFocusedTime',
          );
        }
        final plannedSeconds =
            (widget.todo.durationHours * 3600) +
            (widget.todo.durationMinutes * 60);

        // Check for overdue condition before updating UI
        if (kDebugMode) {
          debugPrint(
            "OVERDUE CHECK IN TICK: task=${widget.todo.text}, "
            "totalFocused=$totalFocusedTime, planned=$plannedSeconds, "
            "isOverdue=${totalFocusedTime >= plannedSeconds}, "
            "promptShown=$_overduePromptShown, "
            "servicePromptShown=${TimerService.instance.hasOverduePromptBeenShown(widget.todo.text)}",
          );
        }

        if (plannedSeconds > 0 &&
            totalFocusedTime >= plannedSeconds &&
            !_overduePromptShown &&
            !TimerService.instance.hasOverduePromptBeenShown(
              widget.todo.text,
            )) {
          _showOverduePrompt();
          return; // Stop further processing in this tick
        }

        // Check for progress bar full condition (but NOT for overdue tasks that user chose to continue)
        if (plannedSeconds > 0 &&
            totalFocusedTime >= plannedSeconds &&
            !_state!.isProgressBarFull &&
            !TimerService.instance.hasUserContinuedOverdue(widget.todo.text)) {
          _showProgressBarFullDialog();
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
      final newCompletedSessions = _state!.completedSessions + 1;

      setState(() {
        _state = _createUpdatedState(
          timerState: 'running',
          currentMode: 'break',
          timeRemaining: _state!.breakDuration,
          currentCycle: newCycle,
          completedSessions: newCompletedSessions,
        );
      });

      widget.notificationService.showNotification(
        title: 'Focus session ended',
        body: 'Time for a break!',
      );
      // Play break start sound if asset exists
      try {
        if (kDebugMode) debugPrint('SOUND: Break timer start.');
        widget.notificationService.playSound('sounds/Break timer start.wav');
      } catch (e) {
        if (kDebugMode) debugPrint('SOUND ERROR (break start): $e');
      }

      // Check if all sessions are complete - but only if progress bar is not already full
      // Progress bar full dialog takes priority over session completion
      if (kDebugMode) {
        debugPrint(
          'SESSION CHECK: newCompletedSessions=$newCompletedSessions, totalCycles=${_state!.totalCycles}, isProgressBarFull=${_state!.isProgressBarFull}',
        );
      }
      if (newCompletedSessions >= (_state!.totalCycles ?? 0) &&
          !_state!.isProgressBarFull) {
        if (kDebugMode) {
          debugPrint('All focus sessions completed.');
        }
        widget.notificationService.showNotification(
          title: 'All Sessions Completed!',
          body: 'Great job focusing on "${widget.todo.text}".',
        );
        _showSessionCompletionDialog();
        return;
      }
    } else {
      setState(() {
        _state = _createUpdatedState(
          timerState: 'running',
          currentMode: 'focus',
          timeRemaining: _state!.focusDuration,
        );
      });

      widget.notificationService.showNotification(
        title: 'Break ended',
        body: 'Time to focus!',
      );
      try {
        if (kDebugMode) debugPrint('SOUND: Focus timer start (after break).');
        widget.notificationService.playSound('sounds/Focus timer start.wav');
      } catch (e) {
        if (kDebugMode) debugPrint('SOUND ERROR (focus start after break): $e');
      }
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
      focusDuration: _state!.focusDuration,
      breakDuration: _state!.breakDuration,
      setTotalCycles: _state!.totalCycles,
      setCurrentCycle: _state!.currentCycle,
    );

    _startTicker();
  }

  Future<void> _showOverduePrompt() async {
    if (kDebugMode) {
      debugPrint('POMODORO: Task is now overdue. Showing prompt.');
      try {
        TimerService.instance.logStateSnapshot('ON OVERDUE PROMPT ENTRY');
      } catch (_) {}
    }
    _overduePromptShown = true; // Prevent showing it again
    // Also inform the central TimerService that this task's overdue prompt has been shown
    try {
      TimerService.instance.markOverduePromptShown(widget.todo.text);
    } catch (_) {}
    _stopTicker(); // Pause the timer

    // HARD SUPPRESSION: Clear the central service so the mini-bar hides immediately when overdue dialog shows.
    // This aligns overdue path with progress-bar-full path (auto-hide screen + minibar while user decides).
    try {
      if (kDebugMode)
        debugPrint(
          'POMODORO: Clearing TimerService for overdue prompt (hide minibar).',
        );
      TimerService.instance.clear();
      try {
        TimerService.instance.logStateSnapshot(
          'AFTER CLEAR FOR OVERDUE PROMPT',
        );
      } catch (_) {}
    } catch (_) {}

    widget.notificationService.showNotification(
      title: 'Task Overdue',
      body: 'Planned time for "${widget.todo.text}" is complete.',
    );
    // Corrected filename (no spaces) and wrapped in a try-catch
    try {
      try {
        widget.notificationService.playSound('sounds/progress bar full.wav');
      } catch (_) {}
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
        try {
          TimerService.instance.logStateSnapshot(
            'USER CONTINUE OVERDUE (BEFORE RESET)',
          );
        } catch (_) {}
      }
      // Mark centrally that the user chose to continue working on this overdue task
      try {
        TimerService.instance.markUserContinuedOverdue(widget.todo.text);
      } catch (_) {}
      // Immediately transition this screen back to the setup state so the
      // user can reconfigure durations before starting a new session.
      if (mounted && _state != null) {
        setState(() {
          _state = TaskTimerState(
            taskId: _state!.taskId,
            timerState: 'idle', // ensures setup UI path
            currentMode: 'focus',
            timeRemaining: _state!.focusDuration ?? 25 * 60,
            focusDuration: _state!.focusDuration ?? 25 * 60,
            breakDuration: _state!.breakDuration ?? 5 * 60,
            totalCycles: _state!.totalCycles ?? _calculateCycles(25),
            completedSessions: 0,
            isProgressBarFull: false,
            allSessionsComplete: false,
            lastFocusedTime: 0,
          );
        });
        // Persist so that reopening also shows setup without requiring a manual reset
        try {
          await _store.save(widget.todo.id.toString(), _state!);
        } catch (_) {}
        if (kDebugMode) {
          debugPrint(
            'POMODORO: Reset to setup after continue-overdue selection. Showing setup screen.',
          );
        }
        // CRITICAL: Clear central service AGAIN to ensure minibar stays hidden after dialog dismissal.
        try {
          if (kDebugMode)
            debugPrint(
              'POMODORO: Clearing TimerService after continue to suppress minibar until user restarts.',
            );
          TimerService.instance.clear();
          try {
            TimerService.instance.logStateSnapshot('AFTER CLEAR ON CONTINUE');
          } catch (_) {}
        } catch (_) {}
      }
    }
  }

  // Helper method to create a new state with updated fields
  TaskTimerState _createUpdatedState({
    String? timerState,
    String? currentMode,
    int? timeRemaining,
    int? focusDuration,
    int? breakDuration,
    int? currentCycle,
    int? totalCycles,
    int? lastFocusedTime,
    int? completedSessions,
    bool? isProgressBarFull,
    bool? allSessionsComplete,
  }) {
    return TaskTimerState(
      taskId: _state!.taskId,
      timerState: timerState ?? _state!.timerState,
      currentMode: currentMode ?? _state!.currentMode,
      timeRemaining: timeRemaining ?? _state!.timeRemaining,
      focusDuration: focusDuration ?? _state!.focusDuration,
      breakDuration: breakDuration ?? _state!.breakDuration,
      currentCycle: currentCycle ?? _state!.currentCycle,
      totalCycles: totalCycles ?? _state!.totalCycles,
      lastFocusedTime: lastFocusedTime ?? _state!.lastFocusedTime,
      completedSessions: completedSessions ?? _state!.completedSessions,
      isProgressBarFull: isProgressBarFull ?? _state!.isProgressBarFull,
      allSessionsComplete: allSessionsComplete ?? _state!.allSessionsComplete,
    );
  }

  // Show progress bar full dialog
  void _showProgressBarFullDialog() {
    if (kDebugMode) {
      debugPrint(
        'POMODORO: Progress bar full - implementing IMMEDIATE HARD RESET',
      );
    }

    // IMMEDIATE HARD RESET when progress bar full dialog appears
    _ticker?.cancel();
    // Suppress automatic mini-bar reactivation after closing.
    TimerService.instance.suppressNextActivation = true;
    try {
      TimerService.instance.clear();
    } catch (_) {}
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Show dialog after closing the screen
    Future.microtask(() {
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
                _handleContinueWorking();
              },
              child: const Text('Continue Working'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleMarkComplete();
              },
              child: const Text('Mark Complete'),
            ),
          ],
        ),
      );
    });

    setState(() {
      final plannedSecondsForClamp =
          (widget.todo.durationHours * 3600) +
          (widget.todo.durationMinutes * 60);
      final defaultFocusSeconds = 25 * 60;
      final clampedFocusSeconds = plannedSecondsForClamp > 0
          ? (plannedSecondsForClamp < defaultFocusSeconds
                ? plannedSecondsForClamp
                : defaultFocusSeconds)
          : defaultFocusSeconds;
      _state = _createUpdatedState(
        timerState: 'idle',
        currentMode: 'focus',
        timeRemaining: clampedFocusSeconds,
        focusDuration: clampedFocusSeconds,
        breakDuration: 300,
        currentCycle: 0, // not started yet
        totalCycles:
            _state?.totalCycles ??
            4, // preserve manual value if user changed it
        lastFocusedTime: 0,
        isProgressBarFull: true,
        allSessionsComplete: false,
      );
    });

    // Notify user and play sound for progress bar full
    try {
      if (kDebugMode) {
        debugPrint('SOUND: Playing progress bar full sound (dialog).');
      }
      widget.notificationService.showNotification(
        title: 'Planned Time Complete',
        body: 'Decide: Continue or mark "${widget.todo.text}" complete.',
      );
      widget.notificationService.playSound('sounds/progress bar full.wav');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SOUND ERROR: $e');
      }
    }
  }

  // Handle continue working after progress bar full
  void _handleContinueWorking() {
    if (kDebugMode) {
      debugPrint(
        'POMODORO: _handleContinueWorking - setting up overdue timer with minibar',
      );
    }
    // User wants to continue: return to SETUP (idle) screen so they can adjust
    // durations & cycles again. Respect any manual cycles input already present.
    final plannedSecondsForClamp =
        (widget.todo.durationHours * 3600) + (widget.todo.durationMinutes * 60);
    final preservedFocusRaw = _state?.focusDuration ?? 25 * 60;
    final preservedFocus = plannedSecondsForClamp > 0
        ? (preservedFocusRaw > plannedSecondsForClamp
              ? plannedSecondsForClamp
              : preservedFocusRaw)
        : preservedFocusRaw;
    final preservedBreak = _state?.breakDuration ?? 5 * 60;
    // If user manually changed cycles text, use it; else keep existing or recalc.
    int manualCycles = int.tryParse(_cyclesController.text.trim()) ?? 0;
    if (manualCycles <= 0) {
      manualCycles =
          _state?.totalCycles ?? _calculateCycles(preservedFocus ~/ 60);
    }

    setState(() {
      _state = TaskTimerState(
        taskId: widget.todo.id.toString(),
        timerState: 'idle', // show setup UI
        currentMode: 'focus',
        timeRemaining: preservedFocus,
        focusDuration: preservedFocus,
        breakDuration: preservedBreak,
        totalCycles: manualCycles,
        currentCycle: 0,
        completedSessions: 0,
        isProgressBarFull: false,
        allSessionsComplete: false,
      );
    });
    // Persist setup state so re-opening reflects idle configuration.
    _store.save(widget.todo.id.toString(), _state!);
    // Ensure central timer is fully cleared & minibar hidden until user presses start.
    TimerService.instance.suppressNextActivation = true;
    TimerService.instance.clear();
    if (kDebugMode) {
      debugPrint('POMODORO: Continue working -> returned to setup (idle)');
    }
    // Close dialog only (pomodoro sheet already closed earlier when progress bar full) if still mounted.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
        color: Colors.red.withOpacity(0.1),
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

  // Handle mark complete after progress bar full
  void _handleMarkComplete() async {
    TimerService.instance.clear();
    await widget.onTaskCompleted();
    Navigator.of(context).pop(); // Close the pomodoro screen
  }

  // Show session completion dialog
  void _showSessionCompletionDialog() {
    setState(() {
      _state = _createUpdatedState(
        allSessionsComplete: true,
        timerState: 'paused',
      );
    });
    _ticker?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('All Sessions Complete!'),
        content: Text(
          'You have completed all ${_state!.totalCycles} focus sessions for this task.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _handleDismissTimer(); // Clear timer and close pomodoro screen
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  // Handle dismiss timer after session completion
  void _handleDismissTimer() {
    TimerService.instance.clear();
    Navigator.of(context).pop(); // Close the pomodoro screen
  }

  // Validate focus duration before starting timer
  bool _validateFocusDuration() {
    final focusMinutes = int.tryParse(_focusController.text.trim()) ?? 25;
    final taskTotalMinutes =
        (widget.todo.durationHours * 60) + widget.todo.durationMinutes;
    // If user continued an overdue task, allow any focus duration (skip rule)
    final continuedOverdue = TimerService.instance.hasUserContinuedOverdue(
      widget.todo.text,
    );
    if (kDebugMode) {
      debugPrint(
        'VALIDATION: focusMinutes=$focusMinutes taskTotalMinutes=$taskTotalMinutes continuedOverdue=$continuedOverdue',
      );
    }
    if (!continuedOverdue && focusMinutes > taskTotalMinutes) {
      _showFocusDurationError(focusMinutes, taskTotalMinutes);
      return false;
    }
    return true;
  }

  // Show focus duration validation error
  void _showFocusDurationError(int focusMinutes, int taskMinutes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid Focus Duration'),
        content: Text(
          'Focus duration ($focusMinutes minutes) cannot be greater than the task duration ($taskMinutes minutes). Please reduce the focus duration or increase the task duration.',
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

    // DEBUG: Log UI decision
    if (kDebugMode) {
      final showSetup =
          (s.timerState == 'paused' && s.timeRemaining == s.focusDuration) ||
          (s.timerState == 'idle');
      debugPrint(
        "UI DEBUG: timerState=${s.timerState}, timeRemaining=${s.timeRemaining}, focusDuration=${s.focusDuration}, showSetup=$showSetup",
      );
    }

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
                      onPressed: () async {
                        // First pause the timer if it's running
                        if (_state?.timerState == 'running') {
                          _stopTicker();
                        }

                        // Reset timer to idle setup preserving any manual cycles entered earlier
                        final preservedCycles =
                            _state?.totalCycles ?? _calculateCycles(25);
                        setState(() {
                          _state = TaskTimerState(
                            taskId: widget.todo.id.toString(),
                            timerState: 'paused',
                            currentMode: 'focus',
                            timeRemaining: _state?.focusDuration ?? 25 * 60,
                            focusDuration: _state?.focusDuration ?? 25 * 60,
                            breakDuration: _state?.breakDuration ?? 5 * 60,
                            totalCycles: preservedCycles,
                            completedSessions: 0,
                            isProgressBarFull: false,
                            allSessionsComplete: false,
                          );
                        });

                        // Clear both the service state and minibar, and suppress reactivation
                        TimerService.instance.suppressNextActivation = true;
                        TimerService.instance.clear();

                        // Persist the reset state so reopening shows initial UI
                        await _store.save(widget.todo.id.toString(), _state!);

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

                  // Check if this is an overdue task that user chose to continue
                  final isOverdueTask =
                      plannedSeconds > 0 &&
                      cached >= plannedSeconds &&
                      TimerService.instance.hasUserContinuedOverdue(
                        widget.todo.text,
                      );

                  return Padding(
                    // Slightly reduced top padding so the progress bar sits
                    // a bit closer to the content above and ultimately
                    // closer to the timer when the large spacer is reduced.
                    padding: const EdgeInsets.only(top: 48.0, bottom: 8.0),
                    child: SizedBox(
                      // Wrapper to control overall space. Height increased
                      // to comfortably contain a thicker progress bar.
                      height: 34,
                      child: isOverdueTask
                          ? _buildOverdueTimeDisplay(cached, plannedSeconds)
                          : ProgressBar(
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
          // Show full interactive settings only in the initial pre-start state or idle state.
          if ((s.timerState == 'paused' &&
                  s.timeRemaining == s.focusDuration) ||
              (s.timerState == 'idle')) ...[
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

                            // Calculate the session progress that will be lost — prefer
                            // the service's cached total focused time when available.
                            final sessionProgress = _state!.lastFocusedTime;
                            final serviceTotalFocused =
                                TimerService.instance.getFocusedTime(
                                  widget.todo.text,
                                ) ??
                                widget.todo.focusedTime;
                            // The reverted focused time should only remove the current
                            // session progress, never drop below the server-known base.
                            final baseFocused = widget.todo.focusedTime;
                            final revertedFocusedTime =
                                (serviceTotalFocused - sessionProgress)
                                    .clamp(baseFocused, serviceTotalFocused)
                                    .toInt();

                            if (kDebugMode) {
                              debugPrint(
                                "RESET: Session progress to revert: ${sessionProgress}s",
                              );
                              debugPrint(
                                "RESET: Service total focused: ${serviceTotalFocused}s -> ${revertedFocusedTime}s (base ${baseFocused}s)",
                              );
                            }

                            // Reset the focused time in the service cache to remove session progress
                            TimerService.instance.setFocusedTime(
                              widget.todo.text,
                              revertedFocusedTime,
                            );

                            // Also update the server to reflect the reset
                            try {
                              await widget.api.updateFocusTime(
                                widget.todo.id,
                                revertedFocusedTime,
                              );
                            } catch (_) {
                              // ignore network errors; local cache keeps the truth
                            }

                            setState(() {
                              _state = _createUpdatedState(
                                timerState: 'paused',
                                timeRemaining: _state!.currentMode == 'focus'
                                    ? _state!.focusDuration
                                    : _state!.breakDuration,
                                lastFocusedTime: 0, // Reset session progress
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
                              focusDuration: _state?.focusDuration,
                              breakDuration: _state?.breakDuration,
                              setTotalCycles: _state?.totalCycles,
                              setCurrentCycle: _state?.currentCycle,
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
                                _state = _createUpdatedState(
                                  timerState: 'paused',
                                );
                                _stopTicker();
                                _store.save(widget.todo.id.toString(), _state!);
                              });
                            } else {
                              // Validate focus duration before starting
                              if (!_validateFocusDuration()) {
                                return; // Stop if validation fails
                              }

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
                                _state = _createUpdatedState(
                                  timerState: 'running',
                                  // Fresh session start: reset per-session accumulator to zero
                                  lastFocusedTime: 0,
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
                          color: Colors.white,
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

                            // ENFORCE SESSION LIMITS: Prevent user from going beyond designated sessions
                            if (isFocus) {
                              final newCompletedSessions =
                                  s.completedSessions + 1;
                              if (newCompletedSessions >=
                                  (s.totalCycles ?? 0)) {
                                // User has completed all their designated sessions
                                if (kDebugMode) {
                                  debugPrint(
                                    'SESSION LIMIT: User attempted to skip beyond designated sessions ($newCompletedSessions >= ${s.totalCycles})',
                                  );
                                }
                                // Show dialog instead of allowing skip
                                widget.notificationService.showNotification(
                                  title: 'All Sessions Completed!',
                                  body:
                                      'You have completed all ${s.totalCycles} focus sessions for "${widget.todo.text}".',
                                );
                                _showSessionCompletionDialog();
                                return; // Don't allow skip
                              }
                            }

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
                              _state = _createUpdatedState(
                                timerState: 'running',
                                currentMode: isFocus ? 'break' : 'focus',
                                timeRemaining: isFocus
                                    ? s.breakDuration
                                    : s.focusDuration,
                                currentCycle: isFocus
                                    ? s.currentCycle + 1
                                    : s.currentCycle,
                                // When skipping focus to break, increment completed sessions
                                completedSessions: isFocus
                                    ? s.completedSessions + 1
                                    : s.completedSessions,
                                // When starting break, reset lastFocusedTime for break tracking
                                // When starting focus, keep current lastFocusedTime to preserve session progress
                                lastFocusedTime: isFocus
                                    ? 0
                                    : s.lastFocusedTime,
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
