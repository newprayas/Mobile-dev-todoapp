import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';

/// Debug-only helpers to exercise notification sounds without cluttering
/// production service code. Wrap calls in kDebugMode checks at call sites.
class NotificationSoundTester {
  final NotificationService _service;
  NotificationSoundTester(this._service);

  Future<void> testBreakSound() async {
    if (!kDebugMode) return;
    await _service.playSound('break_timer_start.wav');
  }

  Future<void> testAllCoreSounds() async {
    if (!kDebugMode) return;
    for (final s in const [
      'break_timer_start.wav',
      'focus_timer_start.wav',
      'progress_bar_full.wav',
    ]) {
      await _service.playSound(s);
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }
}