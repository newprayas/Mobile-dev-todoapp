/// Centralized default Pomodoro timer constants.
/// Keeping these here avoids scattering magic numbers (like 1500, 300) across the codebase.
class TimerDefaults {
  TimerDefaults._();

  /// Default focus session length in seconds (25 minutes).
  static const int focusSeconds = 25 * 60; // 1500

  /// Default break session length in seconds (5 minutes).
  static const int breakSeconds = 5 * 60; // 300

  /// Minimum allowed focus duration (to guard against invalid user input).
  static const int minFocusSeconds = 5 * 60;

  /// Maximum allowed focus duration (2 hours safety cap).
  static const int maxFocusSeconds = 2 * 60 * 60;

  /// Auto-save interval threshold in seconds.
  static const int autoSaveIntervalSeconds = 30;
}
