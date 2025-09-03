import 'package:workmanager/workmanager.dart';
import '../utils/app_constants.dart';

/// Thin abstraction over Workmanager operations used by the timer.
/// Keeps raw plugin API calls centralized for easier mocking & future changes.
class WorkmanagerTimerService {
  Future<void> schedulePomodoroOneOff({
    required Duration delay,
    required Map<String, dynamic> inputData,
  }) async {
    await Workmanager().registerOneOffTask(
      AppConstants.pomodoroTimerTask,
      AppConstants.pomodoroTimerTask,
      initialDelay: delay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
  constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresBatteryNotLow: false,
      ),
      inputData: inputData,
    );
  }

  Future<void> cancelPomodoroTask() async {
    await Workmanager().cancelByUniqueName(AppConstants.pomodoroTimerTask);
  }
}
