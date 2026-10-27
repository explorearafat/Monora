/// A minimal parser for the widespread `.lrc` synchronized-lyrics format.
///
/// Supports:
/// * standard `[mm:ss.xx]` timestamps (one or several per line),
/// * a global `[offset:+ms]` / `[offset:-ms]` tag that shifts every line,
/// * metadata tags such as `[ti:...]`, `[ar:...]` which are ignored for
///   playback but exposed through [LrcContent.metadata].
library;

/// A single timed lyrics line.
class LrcLine {
  const LrcLine({required this.time, required this.text});

  /// Offset from the start of the track at which [text] becomes current.
  final Duration time;

  /// Lyric text for this line; may be empty for instrumental gaps.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is LrcLine && other.time == time && other.text == text;

  @override
  int get hashCode => Object.hash(time, text);

  @override
  String toString() => 'LrcLine(${time.inMilliseconds}ms, "$text")';
}

/// The parsed result of an `.lrc` file.
class LrcContent {
  const LrcContent({
    required this.lines,
    this.metadata = const <String, String>{},
  });

  /// Lines sorted by time. Instrumental-gap lines with empty text are kept so
  /// the UI can collapse consecutive empties if it wants to.
  final List<LrcLine> lines;

  /// Raw metadata tags (title, artist, ...) keyed by lowercase tag name.
  final Map<String, String> metadata;

  /// Whether any lyric line carries actual text.
  bool get hasText => lines.any((line) => line.text.isNotEmpty);
}

class LrcParser {
  static final RegExp _timestampPattern = RegExp(
    r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]',
  );
  static final RegExp _offsetPattern = RegExp(
    r'^\s*\[offset:\s*([+-]?\d+)\s*\]\s*$',
    caseSensitive: false,
  );
  static final RegExp _metadataPattern = RegExp(r'^\[(\w{1,5}):([^\]]*)\]$');

  /// Parses [source]. Returns null when the file contains no usable timed
  /// lines (e.g. plain text without timestamps).
  static LrcContent? parse(String source) {
    Duration? globalOffset;
    final metadata = <String, String>{};
    final lines = <LrcLine>[];

    for (final rawLine in source.split(RegExp(r'\r?\n'))) {
      final offsetMatch = _offsetPattern.firstMatch(rawLine);
      if (offsetMatch != null) {
        globalOffset = Duration(milliseconds: int.parse(offsetMatch.group(1)!));
        continue;
      }

      final timestamps = <Duration>[];
      var index = 0;
      while (true) {
        final match = _timestampPattern.matchAsPrefix(rawLine, index);
        if (match == null) break;
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fractionGroup = match.group(3) ?? '';
        int milliseconds;
        if (fractionGroup.isEmpty) {
          milliseconds = 0;
        } else if (fractionGroup.length == 1) {
          milliseconds = int.parse(fractionGroup) * 100;
        } else if (fractionGroup.length == 2) {
          milliseconds = int.parse(fractionGroup) * 10;
        } else {
          milliseconds = int.parse(fractionGroup.substring(0, 3));
        }
        timestamps.add(
          Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          ),
        );
        index = match.end;
      }

      final text = rawLine.substring(index).trim();
      if (timestamps.isEmpty) {
        // Metadata tags like [ti:Title] — capture, then ignore.
        final metadataMatch = _metadataPattern.firstMatch(rawLine.trim());
        if (metadataMatch != null) {
          metadata[metadataMatch.group(1)!.toLowerCase()] = metadataMatch
              .group(2)!
              .trim();
        }
        continue;
      }
      for (final time in timestamps) {
        lines.add(LrcLine(time: time, text: text));
      }
    }

    if (lines.isEmpty) return null;

    lines.sort((a, b) => a.time.compareTo(b.time));
    final offset = globalOffset;
    if (offset != null) {
      // Standard .lrc convention: a positive offset makes lyrics appear
      // earlier (timestamps shrink); a negative offset delays them.
      final magnitude = Duration(milliseconds: offset.inMilliseconds.abs());
      Duration shift(Duration time) {
        final shifted =
            offset.isNegative ? time + magnitude : time - magnitude;
        return shifted.isNegative ? Duration.zero : shifted;
      }

      return LrcContent(
        lines: [
          for (final line in lines) LrcLine(time: shift(line.time), text: line.text),
        ],
        metadata: metadata,
      );
    }
    return LrcContent(lines: List.unmodifiable(lines), metadata: metadata);
  }

  /// Returns the index of the line that should be highlighted at [position],
  /// or -1 before the first line starts.
  static int activeIndexFor(List<LrcLine> lines, Duration position) {
    var low = 0;
    var high = lines.length - 1;
    var result = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].time <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }
}
