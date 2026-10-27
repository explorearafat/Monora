import 'package:flutter_test/flutter_test.dart';
import 'package:monora/core/utils/formatters.dart';

void main() {
  group('formatDuration', () {
    test('formats minutes and seconds', () {
      expect(formatDuration(const Duration(seconds: 84)), '1:24');
      expect(formatDuration(Duration.zero), '0:00');
    });

    test('formats hours', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('handles null and negative as placeholders', () {
      expect(formatDuration(null), '--:--');
      expect(formatDuration(const Duration(seconds: -5)), '--:--');
    });
  });

  group('formatDurationLong', () {
    test('hours and minutes', () {
      expect(
        formatDurationLong(const Duration(hours: 2, minutes: 24)),
        '2h 24m',
      );
      expect(formatDurationLong(const Duration(hours: 2)), '2h');
    });

    test('minutes only', () {
      expect(formatDurationLong(const Duration(minutes: 45)), '45 min');
    });

    test('seconds fallback', () {
      expect(formatDurationLong(const Duration(seconds: 36)), '36 sec');
    });
  });

  group('formatCount', () {
    test('below one thousand stays plain', () {
      expect(formatCount(843), '843');
    });

    test('thousands get k suffix', () {
      expect(formatCount(2843), '2.8k');
      expect(formatCount(12000), '12k');
    });
  });
}
