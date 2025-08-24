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
          padding: const EdgeInsets.all(8),
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
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.midGray,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              // Styled task title with yellow outline
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
                  todo.text,
                  style: const TextStyle(
                    color: AppColors.brightYellow,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ctl.mode == PomodoroMode.focus ? 'Focus' : 'Break',
                style: const TextStyle(color: AppColors.lightGray),
              ),
              const SizedBox(height: 4),
              IntrinsicWidth(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ctl.isRunning
                          ? (ctl.mode == PomodoroMode.focus
                                ? Colors.redAccent
                                : Colors.greenAccent)
                          : Colors.transparent,
                      width: 3.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 2.0,
                    ),
                    child: Transform.translate(
                      offset: const Offset(0, -4),
                      child: Text(
                        _format(ctl.timeRemaining),
                        style: const TextStyle(
                          color: AppColors.lightGray,
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async {
                      await ctl.skip();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.brightYellow,
                        width: 1.5,
                      ),
                      foregroundColor: AppColors.brightYellow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final partial = ctl.reset();
                      if (partial > 0) {
                        await onFlushToServer(todo.id, partial);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.brightYellow,
                        width: 1.5,
                      ),
                      foregroundColor: AppColors.brightYellow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
