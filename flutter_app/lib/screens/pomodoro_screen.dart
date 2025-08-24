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
          child: PomodoroScreen(
            api: api,
            todo: todo,
            notificationService: notificationService,
            asSheet: true,
          ),
        ),
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

  late TextEditingController _focusController;
  late TextEditingController _breakController;
  late TextEditingController _cyclesController;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _focusController.dispose();
    _breakController.dispose();
    _cyclesController.dispose();
    super.dispose();
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
      _focusController = TextEditingController(
        text: (_state!.focusDuration! ~/ 60).toString(),
      );
      _breakController = TextEditingController(
        text: (_state!.breakDuration! ~/ 60).toString(),
      );
      _cyclesController = TextEditingController(
        text: _state!.totalCycles.toString(),
      );
    });
  }

  void _startTicker() {
    if (kDebugMode) debugPrint("Starting ticker...");
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTicker() {
    if (kDebugMode) debugPrint("Stopping ticker.");
    _ticker?.cancel();
    _ticker = null;
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
      if (rem % 10 == 0) {
        if (kDebugMode) debugPrint('Saving state to local store.');
        await _store.save(widget.todo.id.toString(), _state!);
      }
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
                      onPressed: () => Navigator.of(context).pop(),
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
                              if (kDebugMode) debugPrint("Pausing timer.");
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
                              if (kDebugMode) debugPrint("Starting timer.");
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
