import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale for Monora. Playfair Display carries the brand voice (wordmark,
/// screen headers, lyrics); Inter carries everything functional.
///
/// Styles that participate in light/dark theming are built from a
/// [MonoraPalette] via [MonoraTextStyles.of]; player styles use the fixed
/// immersive colors and are plain constants.
abstract final class MonoraTextStyles {
  static MonoraText of(MonoraPalette palette) => MonoraText(palette);
}

/// Theme-aware bundle of text styles.
class MonoraText {
  const MonoraText(this.palette);

  static MonoraText of(MonoraPalette palette) => MonoraText(palette);

  final MonoraPalette palette;

  // Brand
  TextStyle get wordmark => TextStyle(
    fontFamily: _serif,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    letterSpacing: 0.2,
    color: palette.ink,
  );
  TextStyle get wordmarkSub => TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w500,
    fontSize: 12.5,
    letterSpacing: 0.3,
    color: palette.inkSecondary,
  );

  // Headers
  TextStyle get screenTitle => TextStyle(
    fontFamily: _serif,
    fontWeight: FontWeight.w600,
    fontSize: 28,
    height: 1.15,
    color: palette.ink,
  );
  TextStyle get greeting => TextStyle(
    fontFamily: _serif,
    fontWeight: FontWeight.w600,
    fontSize: 24,
    height: 1.2,
    color: palette.ink,
  );
  TextStyle get greetingSub => TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.35,
    color: palette.inkSecondary,
  );
  TextStyle get sectionTitle => TextStyle(
    fontFamily: _serif,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 1.2,
    color: palette.ink,
  );

  // Track metadata
  TextStyle get trackTitle => TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 1.25,
    color: palette.ink,
  );
  TextStyle get trackSubtitle => TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w400,
    fontSize: 12.5,
    height: 1.3,
    color: palette.inkSecondary,
  );
  TextStyle get meta => TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.3,
    letterSpacing: 0.2,
    color: palette.inkSecondary,
  );
  TextStyle get metaTertiary => TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.3,
    letterSpacing: 0.2,
    color: palette.inkTertiary,
  );

  // Player (fixed immersive colors — identical in both app themes)
  static const TextStyle playerTitle = TextStyle(
    fontFamily: _serif,
    fontWeight: FontWeight.w700,
    fontSize: 27,
    height: 1.15,
    color: Color(0xFFF1EBDF),
  );
  static const TextStyle playerSubtitle = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.3,
    color: Color(0xFFA99F8D),
  );
  static const TextStyle playerTime = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w500,
    fontSize: 11.5,
    letterSpacing: 0.4,
    color: Color(0xFFA99F8D),
  );

  // Lyrics
  static TextStyle lyricsActive(Color color) => TextStyle(
    fontFamily: _serif,
    fontWeight: FontWeight.w600,
    fontSize: 29,
    height: 1.34,
    color: color,
  );
  static TextStyle lyricsIdle(Color color) => TextStyle(
    fontFamily: _serif,
    fontWeight: FontWeight.w400,
    fontSize: 29,
    height: 1.34,
    color: color,
  );

  static const String _serif = 'Playfair';
  static const String _sans = 'Inter';
}
