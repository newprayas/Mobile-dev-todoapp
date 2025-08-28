import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Widget responsible for displaying the UI for configuring the timer before it starts.
/// This shows the focus duration, break time, and cycles input fields.
class PomodoroSetupView extends StatelessWidget {
  final TextEditingController focusController;
  final TextEditingController breakController;
  final TextEditingController cyclesController;
  final Function(String) onFocusChanged;
  final Function(String) onBreakChanged;

  const PomodoroSetupView({
    required this.focusController,
    required this.breakController,
    required this.cyclesController,
    required this.onFocusChanged,
    required this.onBreakChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildInputColumn(
              controller: focusController,
              onChanged: onFocusChanged,
              label: 'Work Duration',
              isTop: true,
            ),
            _buildInputColumn(
              controller: breakController,
              onChanged: onBreakChanged,
              label: 'Break Time',
              isTop: false,
            ),
            _buildInputColumn(
              controller: cyclesController,
              onChanged: null, // Read-only as per UX spec
              label: 'Cycles',
              isTop: true,
              readOnly: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputColumn({
    required TextEditingController controller,
    required Function(String)? onChanged,
    required String label,
    required bool isTop,
    bool readOnly = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isTop) ...[
          Container(
            width: 88,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: Colors.grey.shade700, width: 1.0),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18.0, color: Colors.white),
              decoration: const InputDecoration(border: InputBorder.none),
              readOnly: readOnly,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: 12),
          Container(width: 2, height: 56, color: AppColors.brightYellow),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.0,
              color: AppColors.brightYellow,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.0,
              color: AppColors.brightYellow,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(width: 2, height: 56, color: AppColors.brightYellow),
          const SizedBox(height: 12),
          Container(
            width: 88,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: Colors.grey.shade700, width: 1.0),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18.0, color: Colors.white),
              decoration: const InputDecoration(border: InputBorder.none),
              readOnly: readOnly,
              onChanged: onChanged,
            ),
          ),
        ],
      ],
    );
  }
}
