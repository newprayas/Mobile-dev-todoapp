import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

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

  void _handleSubmit() {
    final String taskName = _taskController.text.trim();
    final int hours = int.tryParse(_hoursController.text) ?? 0;
    final int minutes = int.tryParse(_minutesController.text) ?? 25;

    if (taskName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task name cannot be empty.'),
          backgroundColor: Colors.orange,
        ),
      );
      _taskFocusNode.requestFocus();
      return;
    }

    if (hours == 0 && minutes == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task duration must be greater than 0 minutes.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    widget.onAddTask(taskName, hours, minutes);

    // Clear the task input but keep duration values
    _taskController.clear();
    _taskFocusNode.requestFocus();
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
        Container(
          decoration: BoxDecoration(
            color: AppColors.midGray,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _taskController,
            focusNode: _taskFocusNode,
            style: TextStyle(color: AppColors.lightGray, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'What do you need to do?',
              hintStyle: TextStyle(color: AppColors.mediumGray, fontSize: 16),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
            onSubmitted: (_) => _handleSubmit(),
            maxLines: null,
            textInputAction: TextInputAction.done,
          ),
        ),
        const SizedBox(height: 12),
        // Duration and Add button row
        Row(
          children: [
            // Hours input
            Container(
              width: 100,
              decoration: BoxDecoration(
                color: AppColors.midGray,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  TextField(
                    controller: _hoursController,
                    style: TextStyle(
                      color: AppColors.lightGray,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(12, 12, 30, 12),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.left,
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Text(
                      'h',
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Minutes input
            Container(
              width: 100,
              decoration: BoxDecoration(
                color: AppColors.midGray,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  TextField(
                    controller: _minutesController,
                    style: TextStyle(
                      color: AppColors.lightGray,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(12, 12, 30, 12),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.left,
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Text(
                      'm',
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Add button
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _handleSubmit,
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
