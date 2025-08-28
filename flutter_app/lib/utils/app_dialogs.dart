import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppDialogs {
  static Future<bool?> showSwitchTaskDialog({
    required BuildContext context,
    required String currentTaskName,
    required String newTaskName,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Switch Task'),
        content: Text(
          'Switch to \'$newTaskName\'? This will stop the current session for \'$currentTaskName\' and save its progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brightYellow,
              foregroundColor: Colors.black,
            ),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showOverdueDialog({
    required BuildContext context,
    required String taskName,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Task Complete'),
        content: Text(
          'Planned time is complete for \'$taskName\'. Mark task as done or continue working?',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.actionSecondary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brightYellow,
              foregroundColor: Colors.black,
            ),
            child: const Text('Mark Complete'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showStopSessionDialog({
    required BuildContext context,
    required String taskName,
    required int minutesWorked,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Stop Session'),
        content: Text(
          'Stop session for \'$taskName\'? Your progress of $minutesWorked minutes from this interval will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.priorityHigh,
              foregroundColor: Colors.white,
            ),
            child: const Text('Stop & Save'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showDeleteTaskDialog({
    required BuildContext context,
    required String taskName,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('This will remove the task "$taskName" permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.priorityHigh,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showSignOutDialog({
    required BuildContext context,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.priorityHigh,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showClearCompletedDialog({
    required BuildContext context,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Completed Tasks'),
        content: const Text(
          'This will permanently delete all completed tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.priorityHigh,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  static Future<void> showAddTaskDialog({
    required BuildContext context,
    required Function(String taskName, int hours, int minutes) onAddTask,
  }) async {
    final taskController = TextEditingController();
    final hoursController = TextEditingController(text: '0');
    final minutesController = TextEditingController(text: '25');

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: taskController,
              decoration: const InputDecoration(
                labelText: 'Task Name',
                hintText: 'Enter task name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hoursController,
                    decoration: const InputDecoration(labelText: 'Hours'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: minutesController,
                    decoration: const InputDecoration(labelText: 'Minutes'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final taskName = taskController.text.trim();
              final hours = int.tryParse(hoursController.text) ?? 0;
              final minutes = int.tryParse(minutesController.text) ?? 25;

              if (taskName.isNotEmpty) {
                onAddTask(taskName, hours, minutes);
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brightYellow,
              foregroundColor: Colors.black,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  static Future<void> showAllSessionsCompleteDialog({
    required BuildContext context,
    required int totalCycles,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sessions Complete'),
        content: Text('You have completed all $totalCycles focus sessions!'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brightYellow,
              foregroundColor: Colors.black,
            ),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}
