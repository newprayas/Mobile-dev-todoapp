import 'package:flutter/material.dart';

/// Widget responsible for displaying the formatted "OVERDUE TIME" text.
/// It correctly calculates and shows the time spent beyond the planned duration.
class PomodoroOverdueDisplay extends StatelessWidget {
  final int focusedSeconds;
  final int plannedSeconds;

  const PomodoroOverdueDisplay({
    required this.focusedSeconds,
    required this.plannedSeconds,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Correctly calculate overdue time as the difference between focused and planned time.
    final overdueSeconds = (focusedSeconds - plannedSeconds)
        .clamp(0, double.infinity)
        .toInt();

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
      height: 28.0, // Match ProgressBar height for visual consistency
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
}
