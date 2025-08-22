import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/todo.dart';
import '../theme/app_colors.dart';
import '../services/local_timer_store.dart';
import '../models/task_timer_state.dart';

class PomodoroScreen extends StatefulWidget {
  final ApiService api;
  final Todo todo;
  final bool asSheet;
  const PomodoroScreen({
    required this.api,
    required this.todo,
    this.asSheet = false,
    super.key,
  });

  /// Helper to show this UI as a draggable bottom sheet.
  static Future<void> showAsBottomSheet(
    BuildContext context,
    ApiService api,
    Todo todo,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        // start mostly expanded (~80%) so the user immediately sees the timer,
        // but keep it draggable up to ~96% and collapsible.
        initialChildSize: 0.8,
        minChildSize: 0.12,
        maxChildSize: 0.96,
        expand: false,
        builder: (dctx, scrollCtrl) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollCtrl,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: PomodoroScreen(api: api, todo: todo, asSheet: true),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  final LocalTimerStore _store = LocalTimerStore();
  TaskTimerState? _state;
  Timer? _ticker;

  static const defaultFocusMinutes = 25;
  static const defaultBreakMinutes = 5;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final s = await _store.load(widget.todo.id.toString());
    setState(() {
      _state =
          s ??
          TaskTimerState(
            taskId: widget.todo.id.toString(),
            timerState: 'paused',
            currentMode: 'focus',
            timeRemaining: defaultFocusMinutes * 60,
            focusDuration: defaultFocusMinutes * 60,
            breakDuration: defaultBreakMinutes * 60,
          );
    });
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _tick() async {
    if (_state == null) return;
    if (_state!.timerState != 'running') return;
    final rem = (_state!.timeRemaining ?? 0) - 1;
    if (rem <= 0) {
      // switch mode
      if (_state!.currentMode == 'focus') {
        // reached end of focus; add focused time to server
        final gained = (_state!.focusDuration ?? defaultFocusMinutes * 60);
        await widget.api.updateFocusTime(
          widget.todo.id,
          ((gained) / 60).round(),
        );
        setState(() {
          _state = TaskTimerState(
            taskId: _state!.taskId,
            timerState: 'paused',
            currentMode: 'break',
            timeRemaining: _state!.breakDuration ?? defaultBreakMinutes * 60,
            focusDuration: _state!.focusDuration,
            breakDuration: _state!.breakDuration,
            currentCycle: _state!.currentCycle + 1,
          );
        });
      } else {
        // break finished -> back to focus
        setState(() {
          _state = TaskTimerState(
            taskId: _state!.taskId,
            timerState: 'paused',
            currentMode: 'focus',
            timeRemaining: _state!.focusDuration ?? defaultFocusMinutes * 60,
            focusDuration: _state!.focusDuration,
            breakDuration: _state!.breakDuration,
            currentCycle: _state!.currentCycle,
          );
        });
      }
      await _store.save(widget.todo.id.toString(), _state!);
      _stopTicker();
      return;
    }

    setState(() {
      _state = TaskTimerState(
        taskId: _state!.taskId,
        timerState: _state!.timerState,
        currentMode: _state!.currentMode,
        timeRemaining: rem,
        focusDuration: _state!.focusDuration,
        breakDuration: _state!.breakDuration,
      );
    });
    // persist occasionally
    if (rem % 10 == 0) await _store.save(widget.todo.id.toString(), _state!);
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    if (s == null) return const Center(child: CircularProgressIndicator());

    final total = s.currentMode == 'focus'
        ? (s.focusDuration ?? defaultFocusMinutes * 60)
        : (s.breakDuration ?? defaultBreakMinutes * 60);
    final progress = total > 0
        ? (1.0 - (s.timeRemaining ?? total) / total).clamp(0.0, 1.0)
        : 0.0;

    // Sheet mode
    if (widget.asSheet) {
      const totalCycles = 4;
      final isRunning = s.timerState == 'running';
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            width: 720,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row: title and close
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Text(
                            'Pomodoro Timer',
                            style: TextStyle(
                              color: AppColors.brightYellow,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        if (isRunning) {
                          // pause before closing
                          setState(() {
                            _state = TaskTimerState(
                              taskId: s.taskId,
                              timerState: 'paused',
                              currentMode: s.currentMode,
                              timeRemaining: s.timeRemaining,
                              focusDuration: s.focusDuration,
                              breakDuration: s.breakDuration,
                              currentCycle: s.currentCycle,
                            );
                          });
                          _stopTicker();
                          await _store.save(widget.todo.id.toString(), _state!);
                        }
                        Navigator.of(context).maybePop();
                      },
                      icon: const Icon(Icons.close, color: AppColors.lightGray),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Task chip and mode selectors
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.brightYellow),
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.todo.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Mode presets
                    Row(
                      children: [
                        for (final preset in [1, 5, 3]) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF232323),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                // set durations (UI only)
                                setState(() {
                                  if (preset == 1) {
                                    _state = TaskTimerState(
                                      taskId: s.taskId,
                                      timerState: 'paused',
                                      currentMode: 'focus',
                                      timeRemaining: defaultFocusMinutes * 60,
                                      focusDuration: defaultFocusMinutes * 60,
                                      breakDuration: defaultBreakMinutes * 60,
                                      currentCycle: s.currentCycle,
                                    );
                                  } else if (preset == 5) {
                                    _state = TaskTimerState(
                                      taskId: s.taskId,
                                      timerState: 'paused',
                                      currentMode: 'break',
                                      timeRemaining: defaultBreakMinutes * 60,
                                      focusDuration: s.focusDuration,
                                      breakDuration: defaultBreakMinutes * 60,
                                      currentCycle: s.currentCycle,
                                    );
                                  } else {
                                    _state = TaskTimerState(
                                      taskId: s.taskId,
                                      timerState: 'paused',
                                      currentMode: 'break',
                                      timeRemaining:
                                          defaultBreakMinutes * 60 * 3,
                                      focusDuration: s.focusDuration,
                                      breakDuration:
                                          defaultBreakMinutes * 60 * 3,
                                      currentCycle: s.currentCycle,
                                    );
                                  }
                                });
                              },
                              child: Text(
                                '$preset',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Cycle counter
                Text(
                  'Cycle: ${s.currentCycle + 1} of $totalCycles',
                  style: const TextStyle(color: AppColors.lightGray),
                ),

                const SizedBox(height: 18),

                // Digital timer with stateful border
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRunning ? Colors.red : Colors.grey.shade800,
                      width: 3,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _format(s.timeRemaining ?? 0),
                        style: const TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 56,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.currentMode.toUpperCase(),
                        style: TextStyle(
                          color: s.currentMode == 'focus'
                              ? AppColors.brightYellow
                              : Colors.lightBlueAccent,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Button row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Primary: Pause/Resume
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brightYellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        if (s.timerState == 'running') {
                          setState(() {
                            _state = TaskTimerState(
                              taskId: s.taskId,
                              timerState: 'paused',
                              currentMode: s.currentMode,
                              timeRemaining: s.timeRemaining,
                              focusDuration: s.focusDuration,
                              breakDuration: s.breakDuration,
                              currentCycle: s.currentCycle,
                            );
                          });
                          _stopTicker();
                          await _store.save(widget.todo.id.toString(), _state!);
                        } else {
                          setState(() {
                            _state = TaskTimerState(
                              taskId: s.taskId,
                              timerState: 'running',
                              currentMode: s.currentMode,
                              timeRemaining: s.timeRemaining,
                              focusDuration: s.focusDuration,
                              breakDuration: s.breakDuration,
                              currentCycle: s.currentCycle,
                            );
                          });
                          _startTicker();
                        }
                      },
                      child: Text(
                        s.timerState == 'running'
                            ? 'Pause'
                            : (s.timeRemaining ==
                                      (s.focusDuration ??
                                          defaultFocusMinutes * 60)
                                  ? 'Start'
                                  : 'Resume'),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Secondary: Skip to Break (outlined)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.brightYellow),
                        foregroundColor: AppColors.brightYellow,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        setState(() {
                          _state = TaskTimerState(
                            taskId: s.taskId,
                            timerState: 'paused',
                            currentMode: s.currentMode == 'focus'
                                ? 'break'
                                : 'focus',
                            timeRemaining: s.currentMode == 'focus'
                                ? (s.breakDuration ?? defaultBreakMinutes * 60)
                                : (s.focusDuration ?? defaultFocusMinutes * 60),
                            focusDuration: s.focusDuration,
                            breakDuration: s.breakDuration,
                            currentCycle:
                                s.currentCycle +
                                (s.currentMode == 'focus' ? 1 : 0),
                          );
                        });
                        _stopTicker();
                        await _store.save(widget.todo.id.toString(), _state!);
                      },
                      child: const Text('Skip to Break'),
                    ),

                    const SizedBox(width: 16),

                    // Secondary: Reset
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.brightYellow),
                        foregroundColor: AppColors.brightYellow,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        setState(() {
                          _state = TaskTimerState(
                            taskId: s.taskId,
                            timerState: 'paused',
                            currentMode: 'focus',
                            timeRemaining:
                                s.focusDuration ?? defaultFocusMinutes * 60,
                            focusDuration: s.focusDuration,
                            breakDuration: s.breakDuration,
                            currentCycle: 0,
                          );
                        });
                        _stopTicker();
                        await _store.save(widget.todo.id.toString(), _state!);
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Full-screen fallback (rare)
    return Scaffold(
      appBar: AppBar(title: Text('Pomodoro - ${widget.todo.text}')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              s.currentMode.toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Hero(
                    tag: 'play_${widget.todo.id}',
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey[850],
                        valueColor: AlwaysStoppedAnimation(
                          AppColors.brightYellow,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    _format(s.timeRemaining ?? 0),
                    style: const TextStyle(fontSize: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              onPressed: () async {
                if (s.timerState == 'running') {
                  setState(() {
                    _state = TaskTimerState(
                      taskId: s.taskId,
                      timerState: 'paused',
                      currentMode: s.currentMode,
                      timeRemaining: s.timeRemaining,
                      focusDuration: s.focusDuration,
                      breakDuration: s.breakDuration,
                      currentCycle: s.currentCycle,
                    );
                  });
                  _stopTicker();
                  await _store.save(widget.todo.id.toString(), _state!);
                } else {
                  setState(() {
                    _state = TaskTimerState(
                      taskId: s.taskId,
                      timerState: 'running',
                      currentMode: s.currentMode,
                      timeRemaining: s.timeRemaining,
                      focusDuration: s.focusDuration,
                      breakDuration: s.breakDuration,
                      currentCycle: s.currentCycle,
                    );
                  });
                  _startTicker();
                }
              },
              backgroundColor: s.timerState == 'running'
                  ? Colors.grey[800]
                  : AppColors.brightYellow,
              child: Icon(
                s.timerState == 'running' ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
