import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/todo.dart';
import '../services/local_timer_store.dart';
import '../models/task_timer_state.dart';

class PomodoroScreen extends StatefulWidget {
  final ApiService api;
  final Todo todo;
  const PomodoroScreen({required this.api, required this.todo, super.key});

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
    return Scaffold(
      appBar: AppBar(title: Text('Pomodoro - ${widget.todo.text}')),
      body: Center(
        child: s == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    s.currentMode.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Circular progress + time
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: (() {
                            final total = s.currentMode == 'focus'
                                ? (s.focusDuration ?? defaultFocusMinutes * 60)
                                : (s.breakDuration ?? defaultBreakMinutes * 60);
                            final rem = s.timeRemaining ?? total;
                            if (total <= 0) return 0.0;
                            return (rem / total).clamp(0.0, 1.0);
                          })(),
                          strokeWidth: 10,
                        ),
                        Text(
                          _format(s.timeRemaining ?? 0),
                          style: const TextStyle(fontSize: 28),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Cycles: ${s.currentCycle}'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          // toggle running/paused
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
                            await _store.save(
                              widget.todo.id.toString(),
                              _state!,
                            );
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
                          s.timerState == 'running' ? 'Pause' : 'Start',
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          // stop and reset
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                ],
              ),
      ),
    );
  }
}
