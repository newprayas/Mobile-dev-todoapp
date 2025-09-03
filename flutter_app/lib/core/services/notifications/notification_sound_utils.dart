/// Utility helpers for notification sound handling.
/// Provides pure, easily testable functions with no platform side-effects.

/// Normalizes a provided sound file path (which may include various directory
/// prefixes) into just the file name portion expected under the `sounds/` asset
/// subdirectory.
///
/// Accepted inputs (examples) and their normalized outputs:
/// - `focus_timer_start.wav` => `focus_timer_start.wav`
/// - `sounds/focus_timer_start.wav` => `focus_timer_start.wav`
/// - `assets/sounds/focus_timer_start.wav` => `focus_timer_start.wav`
/// - `assets/focus_timer_start.wav` => `focus_timer_start.wav`
///
/// The function is intentionally tolerant; unknown structures are returned
/// unchanged to avoid accidental data loss.
String normalizeSoundAsset(String rawPath) {
  if (rawPath.isEmpty) return rawPath; // Guard clause: nothing to do.

  String result = rawPath;
  if (result.startsWith('assets/sounds/')) {
    result = result.substring('assets/sounds/'.length);
  } else if (result.startsWith('assets/')) {
    result = result.substring('assets/'.length);
  } else if (result.startsWith('sounds/')) {
    result = result.substring('sounds/'.length);
  }
  return result;
}
