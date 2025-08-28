import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/timer_provider.dart';

/// Widget responsible for displaying the action buttons: "Reset", "Start/Pause/Resume", "Skip", and "Stop".
/// Handles the different button states based on the current timer state.
class PomodoroActionButtons extends StatelessWidget {
  final TimerState timerState;
  final VoidCallback onReset;
  final VoidCallback onPlayPause;
  final VoidCallback onSkip;
  final VoidCallback? onStop; // Optional stop callback

  const PomodoroActionButtons({
    required this.timerState,
    required this.onReset,
    required this.onPlayPause,
    required this.onSkip,
    this.onStop,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = timerState.isRunning;
    // Setup mode when not running and currentCycle is 0 (initial setup state)
    final isSetupMode = !timerState.isRunning && timerState.currentCycle == 0;
    // Show stop button when timer is active (running or paused but not in setup)
    final showStopButton = !isSetupMode && onStop != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showStopButton)
          // Show 4 buttons when timer is active: Reset, Stop, Play/Pause, Skip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.replay_rounded,
                label: 'Reset',
                onPressed: onReset,
                isSecondary: true,
              ),
              _buildActionButton(
                icon: Icons.stop_rounded,
                label: 'Stop',
                onPressed: onStop!,
                isSecondary: true,
                isDestructive: true,
              ),
              _buildMainActionButton(
                icon: isRunning
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                label: isRunning ? 'Pause' : 'Resume',
                onPressed: onPlayPause,
              ),
              _buildActionButton(
                icon: Icons.fast_forward_rounded,
                label: 'Skip',
                onPressed: onSkip,
                isSecondary: true,
              ),
            ],
          )
        else
          // Show 3 buttons in setup mode: Reset, Start, Skip
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
                icon: Icons.play_arrow_rounded,
                label: 'Start',
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
    bool isDestructive = false,
  }) {
    final buttonColor = isDestructive
        ? Colors.redAccent
        : AppColors.brightYellow;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: buttonColor, width: 2.0),
          ),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: const CircleBorder(),
              side: const BorderSide(color: Colors.transparent),
              padding: const EdgeInsets.all(12),
            ),
            onPressed: onPressed,
            child: Icon(
              icon,
              color: isDestructive
                  ? Colors.redAccent
                  : (isSecondary ? AppColors.brightYellow : Colors.white),
              size: 22,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isDestructive ? Colors.redAccent : Colors.white,
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
