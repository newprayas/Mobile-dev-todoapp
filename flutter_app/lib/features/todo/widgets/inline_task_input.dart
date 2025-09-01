import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/debug_logger.dart';

class InlineTaskInput extends StatefulWidget {
  final Function(String taskName, int hours, int minutes) onAddTask;

  const InlineTaskInput({required this.onAddTask, super.key});

  @override
  State<InlineTaskInput> createState() => _InlineTaskInputState();
}

class _InlineTaskInputState extends State<InlineTaskInput> {
  final _taskController = TextEditingController();
  final _hoursController = TextEditingController(text: '0');
  final _minutesController = TextEditingController(text: '25');
  final _taskFocusNode = FocusNode();

  void _onAddButtonPressed() {
    debugLog('InlineTaskInput', '🔥 ADD BUTTON TAPPED!');
    _handleSubmit();
  }

  void _handleSubmit() {
    debugLog(
      'InlineTaskInput',
      '🚀 ADD BUTTON PRESSED - Starting _handleSubmit',
    );
    final String taskName = _taskController.text.trim();
    final int hours = int.tryParse(_hoursController.text) ?? 0;
    final int minutes = int.tryParse(_minutesController.text) ?? 25;

    debugLog(
      'InlineTaskInput',
      'Attempting to add task: "$taskName" (${hours}h ${minutes}m)',
    );

    if (taskName.isEmpty) {
      debugLog('InlineTaskInput', 'Validation failed: Task name is empty.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task name cannot be empty.'),
          backgroundColor: Colors.orange,
        ),
      );
      // Only request focus if there's a validation error, not automatically
      _taskFocusNode.requestFocus();
      return;
    }

    if (hours == 0 && minutes == 0) {
      debugLog('InlineTaskInput', 'Validation failed: Task duration is zero.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task duration must be greater than 0 minutes.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    debugLog('InlineTaskInput', 'Validation passed. Calling onAddTask...');
    widget.onAddTask(taskName, hours, minutes);

    _taskController.clear();
    // Removed automatic focus request to prevent keyboard from appearing automatically
    debugLog('InlineTaskInput', 'Task input fields cleared.');
  }

  @override
  void dispose() {
    _taskController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _taskFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Task text input
        TextField(
          controller: _taskController,
          focusNode: _taskFocusNode,
          style: TextStyle(color: AppColors.lightGray, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'What do you need to do?',
            hintStyle: TextStyle(color: AppColors.mediumGray, fontSize: 16),
            filled: true,
            fillColor: AppColors.midGray,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onSubmitted: (_) => _onAddButtonPressed(),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 12),
        // Duration and Add button row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _DurationInputBox(controller: _hoursController, unit: 'h'),
            const SizedBox(width: 12),
            _DurationInputBox(controller: _minutesController, unit: 'm'),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _onAddButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brightYellow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A specialized, styled input box for duration values (hours or minutes).
class _DurationInputBox extends StatelessWidget {
  final TextEditingController controller;
  final String unit;

  const _DurationInputBox({required this.controller, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.midGray,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                color: AppColors.lightGray,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.start,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: AppColors.mediumGray,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
