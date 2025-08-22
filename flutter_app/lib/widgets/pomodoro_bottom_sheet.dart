import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../services/pomodoro_controller.dart';
import '../theme/app_colors.dart';

class PomodoroBottomSheet extends StatelessWidget {
  final Todo todo;
  final PomodoroController controller;
  final Future<void> Function(int taskId, int addedSeconds) onFlushToServer;

  const PomodoroBottomSheet({
    required this.todo,
    required this.controller,
    required this.onFlushToServer,
    super.key,
  });

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (ctx, _) {
        final ctl = controller;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.midGray,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                todo.text,
                style: const TextStyle(
                  color: AppColors.brightYellow,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                ctl.mode == PomodoroMode.focus ? 'Focus' : 'Break',
                style: const TextStyle(color: AppColors.lightGray),
              ),
              const SizedBox(height: 8),
              Text(
                _format(ctl.timeRemaining),
                style: const TextStyle(
                  color: AppColors.lightGray,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: ctl.isRunning
                        ? () async {
                            await ctl.pause();
                          }
                        : () async {
                            ctl.start(
                              todo.id,
                              focusSec: ctl.focusDuration,
                              breakSec: ctl.breakDuration,
                              cycles: ctl.totalCycles,
                              plannedDurationSec:
                                  (todo.durationHours * 3600) +
                                  (todo.durationMinutes * 60),
                              initialFocusedSeconds: todo.focusedTime,
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brightYellow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      ctl.isRunning ? 'Pause' : 'Start',
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await ctl.skip();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.midGray,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final partial = ctl.reset();
                      if (partial > 0) {
                        await onFlushToServer(todo.id, partial);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.midGray,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
