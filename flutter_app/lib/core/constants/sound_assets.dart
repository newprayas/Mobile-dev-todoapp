/// Centralized sound asset declarations to avoid scattering raw filenames.
/// Provides type-safe access and future extension point (e.g., localization, variants).
enum SoundAsset {
  focusStart('focus_timer_start.wav'),
  breakStart('break_timer_start.wav'),
  sessionComplete('progress_bar_full.wav');

  const SoundAsset(this.fileName);
  final String fileName;
}
