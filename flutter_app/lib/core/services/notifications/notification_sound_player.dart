import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import 'notification_sound_utils.dart';

/// Plays notification-related sounds from assets with resilience & logging.
class NotificationSoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Logger logger = Logger();

  Future<void> playSound(String soundFileName) async {
    try {
      logger.d('[NotificationSoundPlayer] playSound sound=$soundFileName');
      await _audioPlayer.stop();
      final String assetPath = normalizeSoundAsset(soundFileName);
      await Future.delayed(const Duration(milliseconds: 50));
      await _audioPlayer.play(AssetSource('sounds/$assetPath'));
      logger.i('[NotificationSoundPlayer] Sound played sound=$soundFileName');
      if (soundFileName.contains('break_timer_start')) {
        logger.i('[NotificationSoundPlayer] Break timer sound played');
      } else if (soundFileName.contains('progress_bar_full')) {
        logger.i('[NotificationSoundPlayer] Progress bar full sound played');
      }
    } catch (e, st) {
      logger.e('[NotificationSoundPlayer] Error playing $soundFileName err=$e');
      logger.e('[NotificationSoundPlayer] Stack trace: $st');
      if (soundFileName.contains('break_timer_start') ||
          soundFileName.contains('progress_bar_full')) {
        try {
          await _audioPlayer.setSource(AssetSource('sounds/$soundFileName'));
          await _audioPlayer.resume();
          logger.i(
            '[NotificationSoundPlayer] Alternative playback success sound=$soundFileName',
          );
        } catch (alt) {
          logger.e(
            '[NotificationSoundPlayer] Alternative playback failed err=$alt',
          );
        }
      }
    }
  }
}
