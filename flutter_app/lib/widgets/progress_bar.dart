import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_colors.dart';

class ProgressBar extends StatelessWidget {
  final int focusedSeconds;
  final int plannedSeconds;
  final bool isFocusMode;

  const ProgressBar({
    required this.focusedSeconds,
    required this.plannedSeconds,
    this.isFocusMode = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = (plannedSeconds <= 0)
        ? 0.0
        : (focusedSeconds / plannedSeconds).clamp(0.0, 1.0);
    if (kDebugMode) {
      debugPrint(
        'PROGRESS_BAR: focused=$focusedSeconds planned=$plannedSeconds progress=$progress',
      );
    }
    final barHeight = 16.0; // Increased height for better visibility
    final fillColor = isFocusMode ? AppColors.brightYellow : Colors.greenAccent;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 16.0,
        horizontal: 8.0,
      ), // Increased padding
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              Container(
                width: width,
                height: barHeight,
                decoration: BoxDecoration(
                  color:
                      Colors.grey[900], // Darker background for better contrast
                  borderRadius: BorderRadius.circular(barHeight),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: width * progress,
                height: barHeight,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(barHeight),
                  boxShadow: [
                    BoxShadow(
                      color: fillColor.withOpacity(0.18),
                      blurRadius: 8,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
              if (kDebugMode)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
