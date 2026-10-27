import 'package:flutter/material.dart';

/// Monora design tokens.
///
/// Light theme = warm cream paper with near-black ink and a burnt-orange
/// accent, straight from the design showcase. Dark theme inverts the paper
/// while keeping the same warmth.
abstract final class MonoraColors {
  // Light theme.
  static const Color cream = Color(0xFFF4EFE6);
  static const Color creamSurface = Color(0xFFFBF8F1);
  static const Color creamSurfaceAlt = Color(0xFFEAE2D3);
  static const Color creamOutline = Color(0xFFE2DACA);
  static const Color ink = Color(0xFF211D17);
  static const Color inkSecondary = Color(0xFF6F6759);
  static const Color inkTertiary = Color(0xFF9C9280);

  // Dark theme.
  static const Color night = Color(0xFF15110D);
  static const Color nightSurface = Color(0xFF1F1A14);
  static const Color nightSurfaceAlt = Color(0xFF2A241B);
  static const Color nightOutline = Color(0xFF362F24);
  static const Color moonlight = Color(0xFFF1EBDF);
  static const Color moonlightSecondary = Color(0xFFA99F8D);
  static const Color moonlightTertiary = Color(0xFF7C7362);

  // Immersive player surfaces (used on both themes, matches the design's
  // near-black Now Playing screen).
  static const Color playerBg = Color(0xFF16110B);
  static const Color playerSurface = Color(0xFF241C12);
  static const Color playerSurfaceAlt = Color(0xFF32271A);

  // Accent family. The default accent is the showcase's burnt orange.
  static const Color accent = Color(0xFFE5623D);
  static const Color accentDeep = Color(0xFFC24A2B);
  static const Color accentSoft = Color(0xFFF6DCD0);
  static const Color heart = Color(0xFFE5484D);
  static const Color onAccent = Color(0xFFFBF6EC);

  // Logo mark.
  static const Color logoInk = Color(0xFF181511);
  static const Color logoBar = Color(0xFFF5F1E8);

  /// Accent choices offered in Settings → Appearance → Accent Color.
  static const List<AccentOption> accentOptions = [
    AccentOption(
      name: 'Orange',
      primary: Color(0xFFE5623D),
      deep: Color(0xFFC24A2B),
      soft: Color(0xFFF6DCD0),
    ),
    AccentOption(
      name: 'Ember',
      primary: Color(0xFFD7542A),
      deep: Color(0xFFB03F1B),
      soft: Color(0xFFF5D6C6),
    ),
    AccentOption(
      name: 'Sunset',
      primary: Color(0xFFEF8354),
      deep: Color(0xFFCF6537),
      soft: Color(0xFFFAE4D3),
    ),
    AccentOption(
      name: 'Olive',
      primary: Color(0xFF8A8B4F),
      deep: Color(0xFF6C6D3A),
      soft: Color(0xFFE9E9D2),
    ),
    AccentOption(
      name: 'Plum',
      primary: Color(0xFF9C5B6A),
      deep: Color(0xFF7C4451),
      soft: Color(0xFFF0DCE0),
    ),
  ];
}

/// A selectable accent color family.
class AccentOption {
  const AccentOption({
    required this.name,
    required this.primary,
    required this.deep,
    required this.soft,
  });

  final String name;
  final Color primary;
  final Color deep;
  final Color soft;
}

/// Resolved, theme-aware color bundle consumed through the inherited theme
/// extension so screens never hard-code light/dark values.
@immutable
class MonoraPalette extends ThemeExtension<MonoraPalette> {
  const MonoraPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.outline,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.accent,
    required this.accentDeep,
    required this.accentSoft,
    required this.onAccent,
    required this.heart,
    required this.logoInk,
    required this.logoBar,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color outline;
  final Color ink;
  final Color inkSecondary;
  final Color inkTertiary;
  final Color accent;
  final Color accentDeep;
  final Color accentSoft;
  final Color onAccent;
  final Color heart;
  final Color logoInk;
  final Color logoBar;

  static const light = MonoraPalette(
    background: MonoraColors.cream,
    surface: MonoraColors.creamSurface,
    surfaceAlt: MonoraColors.creamSurfaceAlt,
    outline: MonoraColors.creamOutline,
    ink: MonoraColors.ink,
    inkSecondary: MonoraColors.inkSecondary,
    inkTertiary: MonoraColors.inkTertiary,
    accent: MonoraColors.accent,
    accentDeep: MonoraColors.accentDeep,
    accentSoft: MonoraColors.accentSoft,
    onAccent: MonoraColors.onAccent,
    heart: MonoraColors.heart,
    logoInk: MonoraColors.logoInk,
    logoBar: MonoraColors.logoBar,
  );

  static const dark = MonoraPalette(
    background: MonoraColors.night,
    surface: MonoraColors.nightSurface,
    surfaceAlt: MonoraColors.nightSurfaceAlt,
    outline: MonoraColors.nightOutline,
    ink: MonoraColors.moonlight,
    inkSecondary: MonoraColors.moonlightSecondary,
    inkTertiary: MonoraColors.moonlightTertiary,
    accent: MonoraColors.accent,
    accentDeep: MonoraColors.accentDeep,
    accentSoft: Color(0xFF46322A),
    onAccent: MonoraColors.onAccent,
    heart: MonoraColors.heart,
    logoInk: Color(0xFF0E0C09),
    logoBar: MonoraColors.moonlight,
  );

  @override
  MonoraPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? outline,
    Color? ink,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? accent,
    Color? accentDeep,
    Color? accentSoft,
    Color? onAccent,
    Color? heart,
    Color? logoInk,
    Color? logoBar,
  }) {
    return MonoraPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      outline: outline ?? this.outline,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkTertiary: inkTertiary ?? this.inkTertiary,
      accent: accent ?? this.accent,
      accentDeep: accentDeep ?? this.accentDeep,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      heart: heart ?? this.heart,
      logoInk: logoInk ?? this.logoInk,
      logoBar: logoBar ?? this.logoBar,
    );
  }

  /// Returns the palette recolored with a user-chosen accent family.
  MonoraPalette withAccent(AccentOption option) => copyWith(
    accent: option.primary,
    accentDeep: option.deep,
    accentSoft: option.soft,
  );

  @override
  MonoraPalette lerp(MonoraPalette? other, double t) {
    if (other == null) return this;
    return MonoraPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkTertiary: Color.lerp(inkTertiary, other.inkTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      heart: Color.lerp(heart, other.heart, t)!,
      logoInk: Color.lerp(logoInk, other.logoInk, t)!,
      logoBar: Color.lerp(logoBar, other.logoBar, t)!,
    );
  }
}

/// Convenience accessor: `context.monora`.
extension MonoraPaletteContext on BuildContext {
  MonoraPalette get monora =>
      Theme.of(this).extension<MonoraPalette>() ?? MonoraPalette.light;
}
