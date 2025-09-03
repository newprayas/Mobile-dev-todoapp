import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../../core/constants/timer_defaults.dart';
import '../../../core/data/todo_repository.dart';
import '../providers/timer_provider.dart';

/// Handles periodic autosaving of focused time to the repository.
/// Extracted from `TimerNotifier` to reduce its size and isolate side effects.
class TimerAutoSaveService {
  final TimerNotifier _notifier;
  final Ref _ref;
  Timer? _autoSaveTimer;
  bool _isAutoSaving = false;
  int _lastAutoSavedSeconds = 0;
  final Logger logger = Logger();

  TimerAutoSaveService(this._notifier, this._ref);

  void start() {
    stop();
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: TimerDefaults.autoSaveIntervalSeconds),
      (_) => triggerDeferredAutoSave(),
    );
  }

  void stop() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  void resetLastSavedForTask(int taskId) {
    _lastAutoSavedSeconds = _notifier.state.focusedTimeCache[taskId] ?? 0;
  }

  void triggerDeferredAutoSave() {
    final int? taskId = _notifier.state.activeTaskId;
    if (taskId == null) return;
    final int currentFocused = _notifier.state.focusedTimeCache[taskId] ?? 0;
    if (currentFocused - _lastAutoSavedSeconds <
        TimerDefaults.autoSaveIntervalSeconds)
      return;
    _autoSaveFocusedTime(todoId: taskId);
  }

  Future<void> forceSaveIfNeeded() async {
    final int? taskId = _notifier.state.activeTaskId;
    if (taskId == null) return;
    await _autoSaveFocusedTime(todoId: taskId, force: true);
  }

  Future<void> _autoSaveFocusedTime({
    required int todoId,
    bool force = false,
  }) async {
    final int? taskId = _notifier.state.activeTaskId;
    if (taskId == null) return;
    final int currentFocused = _notifier.state.focusedTimeCache[taskId] ?? 0;
    if (!force && currentFocused <= _lastAutoSavedSeconds) return;
    if (_isAutoSaving) return;
    _isAutoSaving = true;
    try {
      final todoRepository = _ref.read(todoRepositoryProvider);
      await todoRepository.updateFocusTime(todoId, currentFocused);
      _lastAutoSavedSeconds = currentFocused;
      await _notifier.persistState();
    } catch (e) {
      logger.e('[TimerAutoSaveService] Error auto-saving focused time: $e');
    } finally {
      _isAutoSaving = false;
    }
  }
}
