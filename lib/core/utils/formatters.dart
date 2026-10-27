/// Formatting helpers shared across the app.
library;

/// Formats a duration as `m:ss` (or `h:mm:ss` for an hour or longer).
String formatDuration(Duration? duration) {
  if (duration == null || duration.isNegative) return '--:--';
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final twoDigits = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$twoDigits';
  }
  return '$minutes:$twoDigits';
}

/// Formats a duration as a compact human label, e.g. `2h 24m`, `45m`, `36s`.
String formatDurationLong(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours > 0) {
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) return '$minutes min';
  return '${duration.inSeconds} sec';
}

/// Formats a large count with a `k` suffix, e.g. `2,843` -> `2.8k`.
String formatCount(int count) {
  if (count < 1000) return '$count';
  final k = count / 1000;
  final text = k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1);
  return '${text}k';
}
