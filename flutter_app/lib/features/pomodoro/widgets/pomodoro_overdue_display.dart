import 'package:flutter/material.dart';

/// Widget responsible for displaying the formatted "OVERDUE TIME" text.
/// Shows how much time has been spent beyond the planned duration.
/// In permanent overdue mode, shows total focused time.
class PomodoroOverdueDisplay extends StatelessWidget {
  final int focusedSeconds;
  final int plannedSeconds;
  final bool isPermanentOverdueMode;

  const PomodoroOverdueDisplay({
    required this.focusedSeconds,
    required this.plannedSeconds,
    this.isPermanentOverdueMode = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // In permanent overdue mode, show total focused time as overdue
    // In normal overdue mode, show time beyond planned duration
    final overdueSeconds = isPermanentOverdueMode
        ? focusedSeconds
        : (focusedSeconds - plannedSeconds).clamp(0, double.infinity).toInt();

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
}
