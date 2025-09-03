import 'package:audioplayers/audioplayers.dart';
import '../../utils/debug_logger.dart';
import 'notification_sound_utils.dart';

/// Plays notification-related sounds from assets with resilience & logging.
class NotificationSoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> playSound(String soundFileName) async {
    try {
      debugLog('NotificationSoundPlayer', 'playSound sound=$soundFileName');
      await _audioPlayer.stop();
      final String assetPath = normalizeSoundAsset(soundFileName);
      await Future.delayed(const Duration(milliseconds: 50));
      await _audioPlayer.play(AssetSource('sounds/$assetPath'));
      debugLog('NotificationSoundPlayer', 'Sound played sound=$soundFileName');
      if (soundFileName.contains('break_timer_start')) {
        debugLog('NotificationSoundPlayer', 'Break timer sound played');
      } else if (soundFileName.contains('progress_bar_full')) {
        debugLog('NotificationSoundPlayer', 'Progress bar full sound played');
      }
    } catch (e, st) {
      debugLog('NotificationSoundPlayer', 'Error playing $soundFileName err=$e');
      debugLog('NotificationSoundPlayer', 'Stack trace: $st');
      if (soundFileName.contains('break_timer_start') || soundFileName.contains('progress_bar_full')) {
        try {
          await _audioPlayer.setSource(AssetSource('sounds/$soundFileName'));
          await _audioPlayer.resume();
          debugLog('NotificationSoundPlayer', 'Alternative playback success sound=$soundFileName');
        } catch (alt) {
          debugLog('NotificationSoundPlayer', 'Alternative playback failed err=$alt');
        }
      }
    }
  }
}
