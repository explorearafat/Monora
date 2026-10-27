import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monora/app/theme/app_colors.dart';
import 'package:monora/app/theme/app_theme.dart';
import 'package:monora/core/widgets/common.dart';

Widget _host(Widget child, {AccentOption accent = const DefaultAccent()}) {
  return MaterialApp(
    theme: MonoraTheme.light(accent),
    home: Scaffold(body: child),
  );
}

/// Sentinel accent so the test doesn't depend on option ordering.
class DefaultAccent implements AccentOption {
  const DefaultAccent();

  @override
  Color get deep => MonoraColors.accentDeep;

  @override
  String get name => 'Orange';

  @override
  Color get primary => MonoraColors.accent;

  @override
  Color get soft => MonoraColors.accentSoft;
}

void main() {
  group('MonoraTheme', () {
    testWidgets('light theme exposes the cream palette extension', (
      tester,
    ) async {
      late MonoraPalette observed;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              observed = context.monora;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(observed.background, MonoraColors.cream);
      expect(observed.ink, MonoraColors.ink);
      expect(observed.accent, MonoraColors.accent);
    });

    test('withAccent swaps the accent family', () {
      const custom = AccentOption(
        name: 'Plum',
        primary: Color(0xFF9C5B6A),
        deep: Color(0xFF7C4451),
        soft: Color(0xFFF0DCE0),
      );
      final recolored = MonoraPalette.light.withAccent(custom);
      expect(recolored.accent, custom.primary);
      expect(recolored.accentDeep, custom.deep);
      // Untouched tokens stay put.
      expect(recolored.background, MonoraColors.cream);
    });

    test('palette lerp interpolates background', () {
      final mid = MonoraPalette.light.lerp(MonoraPalette.dark, 0.5);
      expect(
        mid.background,
        Color.lerp(MonoraColors.cream, MonoraColors.night, 0.5),
      );
    });
  });

  group('MonoraLogo', () {
    testWidgets('paints inside its box at small and large sizes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [MonoraLogo(size: 24), MonoraLogo(size: 96)],
          ),
        ),
      );
      expect(find.byType(MonoraLogo), findsNWidgets(2));
      final small = tester.getSize(
        find.descendant(
          of: find.byType(MonoraLogo).first,
          matching: find.byType(CustomPaint),
        ),
      );
      expect(small.width, 24);
    });
  });

  group('Pressable', () {
    testWidgets('fires onTap and reports pressed scale state', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          Center(
            child: Pressable(
              onTap: () => taps++,
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(width: 80, height: 48),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(Pressable));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('disabled Pressable ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          Center(
            child: Pressable(
              onTap: () => taps++,
              enabled: false,
              child: const SizedBox(width: 80, height: 48),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(Pressable), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(taps, 0);
    });
  });

  group('EmptyState', () {
    testWidgets('renders title, message and working action', (tester) async {
      var acted = false;
      await tester.pumpWidget(
        _host(
          EmptyState(
            icon: Icons.music_off_rounded,
            title: 'No music found',
            message: 'Rescan to try again.',
            actionLabel: 'Rescan',
            onAction: () => acted = true,
          ),
        ),
      );
      expect(find.text('No music found'), findsOneWidget);
      expect(find.text('Rescan to try again.'), findsOneWidget);
      await tester.tap(find.text('Rescan'));
      await tester.pumpAndSettle();
      expect(acted, isTrue);
    });
  });
}
