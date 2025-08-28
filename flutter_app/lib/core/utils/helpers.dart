String formatTime(int seconds) {
  final minutes = (seconds / 60).floor().toString().padLeft(2, '0');
  final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remainingSeconds';
}
