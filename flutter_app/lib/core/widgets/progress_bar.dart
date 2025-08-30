import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_colors.dart';

class ProgressBar extends StatelessWidget {
  final int focusedSeconds;
  final int plannedSeconds;
  final double barHeight;

  const ProgressBar({
    required this.focusedSeconds,
    required this.plannedSeconds,
    this.barHeight = 16.0, // Default height for standard progress bars
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
    final fillColor = AppColors.brightYellow; // Always use yellow as requested
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 1.0, // Corrected from 16.0 to fit within parent SizedBox
        horizontal: 8.0,
      ), // Increased padding
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final width = constraints.maxWidth;
          final progressWidth = width * progress;
          if (kDebugMode) {
            debugPrint(
              'PROGRESS_BAR_UI: maxWidth=$width, progress=$progress, calculatedWidth=$progressWidth, maxHeight=${constraints.maxHeight}',
            );
          }
          // Determine text color based on progress for better visibility
          final textColor = progress > 0.5
              ? Colors.black
              : Colors.white.withAlpha((255 * 0.9).round());

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
                width: progressWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(barHeight),
                  boxShadow: [
                    BoxShadow(
                      color: fillColor.withAlpha((255 * 0.18).round()),
                      blurRadius: 8,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: textColor,
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
