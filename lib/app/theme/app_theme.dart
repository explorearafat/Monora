import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Motion vocabulary shared by the whole app so transitions feel like one
/// system rather than per-screen improvisations.
abstract final class MonoraMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);
  static const Duration page = Duration(milliseconds: 420);

  /// The signature curve: quick departure, gentle settle.
  static const Curve emphasized = Cubic(0.22, 1.0, 0.36, 1.0);

  /// Softer curve for continuous/ambient animations.
  static const Curve gentle = Curves.easeOutCubic;

  /// Press feedback.
  static const Duration press = Duration(milliseconds: 110);
}

/// Builds light and dark [ThemeData] for the app.
abstract final class MonoraTheme {
  static ThemeData light(AccentOption accent) =>
      _build(MonoraPalette.light.withAccent(accent), Brightness.light);

  static ThemeData dark(AccentOption accent) =>
      _build(MonoraPalette.dark.withAccent(accent), Brightness.dark);

  static ThemeData _build(MonoraPalette palette, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
      primary: palette.accent,
      secondary: palette.accentDeep,
      surface: palette.background,
      surfaceContainerHighest: palette.surfaceAlt,
    ).copyWith(surfaceTint: Colors.transparent);

    final textTheme = _textTheme(palette);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      splashFactory: InkSparkle.splashFactory,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: palette.ink, size: 22),
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: palette.background,
                systemNavigationBarIconBrightness: Brightness.dark,
              )
            : SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: palette.background,
                systemNavigationBarIconBrightness: Brightness.light,
              ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 64,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? palette.ink
                : palette.inkTertiary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Inter',
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? palette.ink
                : palette.inkTertiary,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        padding: EdgeInsets.zero,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: false,
      ),
      dividerTheme: DividerThemeData(
        color: palette.outline,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 13.5,
          color: palette.background,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 1.45,
          color: palette.inkSecondary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.onAccent
              : palette.background,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : palette.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : palette.outline,
        ),
      ),
    );
  }

  static TextTheme _textTheme(MonoraPalette palette) {
    final sans = 'Inter';
    final serif = 'Playfair';
    return TextTheme(
      displaySmall: TextStyle(
        fontFamily: serif,
        fontWeight: FontWeight.w600,
        fontSize: 32,
        height: 1.15,
        color: palette.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: serif,
        fontWeight: FontWeight.w600,
        fontSize: 26,
        height: 1.15,
        color: palette.ink,
      ),
      titleLarge: TextStyle(
        fontFamily: serif,
        fontWeight: FontWeight.w600,
        fontSize: 19,
        height: 1.2,
        color: palette.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: sans,
        fontWeight: FontWeight.w600,
        fontSize: 15.5,
        height: 1.25,
        color: palette.ink,
      ),
      titleSmall: TextStyle(
        fontFamily: sans,
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
        height: 1.25,
        color: palette.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: sans,
        fontWeight: FontWeight.w400,
        fontSize: 15,
        height: 1.4,
        color: palette.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: sans,
        fontWeight: FontWeight.w400,
        fontSize: 13.5,
        height: 1.4,
        color: palette.inkSecondary,
      ),
      bodySmall: TextStyle(
        fontFamily: sans,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        height: 1.35,
        color: palette.inkTertiary,
      ),
      labelLarge: TextStyle(
        fontFamily: sans,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.2,
        color: palette.ink,
      ),
      labelMedium: TextStyle(
        fontFamily: sans,
        fontWeight: FontWeight.w500,
        fontSize: 12.5,
        height: 1.25,
        color: palette.inkSecondary,
      ),
      labelSmall: TextStyle(
        fontFamily: sans,
        fontWeight: FontWeight.w500,
        fontSize: 11,
        height: 1.25,
        letterSpacing: 0.3,
        color: palette.inkTertiary,
      ),
    );
  }
}
