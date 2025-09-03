import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/timer_defaults.dart';
import '../models/timer_state.dart';

/// Widget responsible for displaying the actively running timer, cycle count, and mode.
/// This shows the timer display, current cycle information, and focus/break mode indicators.
class PomodoroTimerView extends StatelessWidget {
  final TimerState timerState;

  const PomodoroTimerView({required this.timerState, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${(timerState.focusDurationSeconds ?? TimerDefaults.focusSeconds) ~/ 60} / ${(timerState.breakDurationSeconds ?? TimerDefaults.breakSeconds) ~/ 60} / ${timerState.totalCycles}',
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
                    color: timerState.currentMode == 'focus'
                        ? Colors.redAccent
                        : Colors.greenAccent,
                    width: 6.0,
                  ),
                  borderRadius: BorderRadius.circular(14.0),
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    _formatTime(timerState.timeRemaining),
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

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
