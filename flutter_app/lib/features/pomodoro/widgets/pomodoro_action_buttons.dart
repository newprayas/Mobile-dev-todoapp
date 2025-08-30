import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/timer_provider.dart';

/// Widget responsible for displaying the action buttons: "Reset", "Start/Pause/Resume", and "Skip".
class PomodoroActionButtons extends StatelessWidget {
  final TimerState timerState;
  final VoidCallback onReset;
  final VoidCallback onPlayPause;
  final VoidCallback onSkip;

  const PomodoroActionButtons({
    required this.timerState,
    required this.onReset,
    required this.onPlayPause,
    required this.onSkip,
    // The onStop callback is removed as it's now handled by the parent screen.
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = timerState.isRunning;
    final isSetupMode = !timerState.isRunning && timerState.currentCycle == 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.replay_rounded,
              label: 'Reset',
              onPressed: onReset,
              isSecondary: true,
            ),
            _buildMainActionButton(
              icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              label: isSetupMode ? 'Start' : (isRunning ? 'Pause' : 'Resume'),
              onPressed: onPlayPause,
            ),
            _buildActionButton(
              icon: Icons.fast_forward_rounded,
              label: 'Skip',
              onPressed: onSkip,
              isSecondary: true,
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isSecondary = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.brightYellow, width: 2.0),
          ),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: const CircleBorder(),
              side: const BorderSide(color: Colors.transparent),
              padding: const EdgeInsets.all(12),
            ),
            onPressed: onPressed,
            child: Icon(icon, color: AppColors.brightYellow, size: 22),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMainActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: FloatingActionButton(
            backgroundColor: AppColors.brightYellow,
            onPressed: onPressed,
            child: Icon(icon, color: Colors.black, size: 40),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
