import 'package:flutter_test/flutter_test.dart';
import 'package:monora/core/utils/lrc_parser.dart';

void main() {
  group('LrcParser.parse', () {
    test('parses simple timestamps and sorts lines', () {
      final content = LrcParser.parse('''
[00:12.00]Second line
[00:03.50]First line
''');
      expect(content, isNotNull);
      expect(content!.lines, hasLength(2));
      expect(content.lines[0].text, 'First line');
      expect(
        content.lines[0].time,
        const Duration(seconds: 3, milliseconds: 500),
      );
      expect(content.lines[1].time, const Duration(seconds: 12));
    });

    test('handles multiple timestamps on one line', () {
      final content = LrcParser.parse('[00:01.00][01:02.00]Chorus');
      expect(content!.lines, hasLength(2));
      expect(content.lines[0].time, const Duration(seconds: 1));
      expect(content.lines[1].time, const Duration(minutes: 1, seconds: 2));
      expect(content.lines.every((line) => line.text == 'Chorus'), isTrue);
    });

    test('parses metadata tags and offset', () {
      final content = LrcParser.parse('''
[ti:After Hours]
[ar:The Weeknd]
[offset:-500]
[00:01.00]Hello
''');
      expect(content!.metadata['ti'], 'After Hours');
      expect(content.metadata['ar'], 'The Weeknd');
      // offset -500 means lyrics are 500ms early; parser shifts forward.
      expect(
        content.lines.first.time,
        const Duration(seconds: 1) + const Duration(milliseconds: 500),
      );
    });

    test('positive offset shifts lines earlier in wall time', () {
      final content = LrcParser.parse('[offset:200]\n[00:10.00]X');
      expect(
        content!.lines.first.time,
        const Duration(seconds: 10) - const Duration(milliseconds: 200),
      );
    });

    test('returns null for plain text without timestamps', () {
      expect(LrcParser.parse('just some words\nno tags here'), isNull);
    });

    test('keeps instrumental gap lines', () {
      final content = LrcParser.parse(
        '[00:01.00]Intro\n[00:05.00]\n[00:08.00]Verse',
      );
      expect(content!.lines, hasLength(3));
      expect(content.lines[1].text, isEmpty);
      expect(content.hasText, isTrue);
    });

    test('all-empty lines are reported as having no text', () {
      final content = LrcParser.parse('[00:01.00]\n[00:02.00]');
      expect(content, isNotNull);
      expect(content!.hasText, isFalse);
    });
  });

  group('LrcParser.activeIndexFor', () {
    final lines = [
      const LrcLine(time: Duration(seconds: 1), text: 'a'),
      const LrcLine(time: Duration(seconds: 5), text: 'b'),
      const LrcLine(time: Duration(seconds: 9), text: 'c'),
    ];

    test('before the first line', () {
      expect(
        LrcParser.activeIndexFor(lines, const Duration(milliseconds: 500)),
        -1,
      );
    });

    test('inside a line window', () {
      expect(LrcParser.activeIndexFor(lines, const Duration(seconds: 1)), 0);
      expect(LrcParser.activeIndexFor(lines, const Duration(seconds: 6)), 1);
    });

    test('at the exact boundary', () {
      expect(LrcParser.activeIndexFor(lines, const Duration(seconds: 5)), 1);
    });

    test('after the last line', () {
      expect(LrcParser.activeIndexFor(lines, const Duration(seconds: 90)), 2);
    });
  });
}
