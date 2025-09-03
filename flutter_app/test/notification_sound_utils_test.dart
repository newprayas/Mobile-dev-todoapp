import 'package:flutter_test/flutter_test.dart';
import 'package:focus_timer_app/core/services/notifications/notification_sound_utils.dart';

void main() {
  group('normalizeSoundAsset', () {
    test('leaves simple filename unchanged', () {
      expect(normalizeSoundAsset('focus_timer_start.wav'), 'focus_timer_start.wav');
    });
    test('strips sounds/ prefix', () {
      expect(normalizeSoundAsset('sounds/focus_timer_start.wav'), 'focus_timer_start.wav');
    });
    test('strips assets/sounds/ prefix', () {
      expect(normalizeSoundAsset('assets/sounds/focus_timer_start.wav'), 'focus_timer_start.wav');
    });
    test('strips assets/ prefix', () {
      expect(normalizeSoundAsset('assets/focus_timer_start.wav'), 'focus_timer_start.wav');
    });
    test('returns empty unchanged', () {
      expect(normalizeSoundAsset(''), '');
    });
  });
}
