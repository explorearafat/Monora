import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../providers/app_providers.dart';
import '../../providers/player_providers.dart';
import '../permission/permission_screen.dart';
import '../shell/shell_screen.dart';

/// Launch screen: Monora's organic wave artwork, brand mark, and a short
/// initialization sequence (permission check → library scan → session
/// restore) before landing on either the shell or the permission screen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    Future<void>.delayed(const Duration(milliseconds: 1500), _route);
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _route() async {
    if (!mounted || _navigated) return;
    _navigated = true;
    // Settle the OS permission check first: on a slow cold start the status
    // refresh can lag behind this timer, and routing on "undetermined" sent
    // already-granted users back to the permission screen on every launch.
    await ref.read(permissionProvider.notifier).refresh();
    if (!mounted) return;
    final permission = ref.read(permissionProvider);
    if (!permission.canReadLibrary) {
      _go(const PermissionScreen());
      return;
    }
    // Existing installs never saw the notification-permission dialog; ask
    // once (only while undetermined) so the media notification can appear.
    unawaited(ref.read(permissionProvider.notifier).ensureNotifications());
    // Warm the library before the shell so Home opens with content ready.
    try {
      await ref.read(libraryProvider.future);
    } on Exception {
      // The shell surfaces the error state; don't block navigation.
    }
    if (!mounted) return;
    await restoreSessionIfNeeded(ref);
    if (!mounted) return;
    _go(const ShellScreen());
  }

  void _go(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: palette.background,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: palette.background,
        body: AnimatedBuilder(
        animation: _entrance,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_entrance.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: WaveArtwork(
                  progress: t,
                  accent: palette.accent,
                  ink: palette.ink,
                ),
              ),
              Center(
                child: Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MonoraLogo(size: 92),
                        const SizedBox(height: 22),
                        Text(
                          'Monora',
                          style: TextStyle(
                            fontFamily: 'Playfair',
                            fontWeight: FontWeight.w700,
                            fontSize: 40,
                            letterSpacing: 0.4,
                            color: _waveOverlay(t)
                                ? palette.logoBar
                                : palette.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your sound. Your space.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            letterSpacing: 0.6,
                            color: _waveOverlay(t)
                                ? palette.logoBar.withValues(alpha: 0.75)
                                : palette.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  /// During the first half of the entrance the text sits on the light paper;
  /// it drifts down into the dark wave as the artwork settles.
  bool _waveOverlay(double t) => t > 0.55;
}

/// Layered bezier waves: a soft orange swash behind a deep ink dune, matching
/// the splash panel in the design showcase.
class WaveArtwork extends CustomPainter {
  const WaveArtwork({
    required this.progress,
    required this.accent,
    required this.ink,
  });

  /// Fully settled artwork (used by the permission screen).
  const WaveArtwork.static()
    : progress = 1,
      accent = MonoraColors.accent,
      ink = MonoraColors.logoInk;

  final double progress;
  final Color accent;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final orangePaint = Paint()..color = accent.withValues(alpha: 0.9);
    final inkPaint = Paint()..color = ink;
    final softPaint = Paint()..color = accent.withValues(alpha: 0.28);

    final w = size.width;
    final h = size.height;
    final rise = (1 - progress) * h * 0.18;

    // Faint echo wave (top).
    final echo = Path()
      ..moveTo(0, h * 0.30 + rise)
      ..cubicTo(
        w * 0.30,
        h * 0.10 + rise,
        w * 0.55,
        h * 0.42 + rise,
        w,
        h * 0.22 + rise,
      )
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(echo, softPaint);

    // Orange swash.
    final orange = Path()
      ..moveTo(0, h * 0.52 + rise)
      ..cubicTo(
        w * 0.28,
        h * 0.30 + rise,
        w * 0.52,
        h * 0.62 + rise,
        w,
        h * 0.38 + rise,
      )
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(orange, orangePaint);

    // Deep ink dune at the bottom.
    final dune = Path()
      ..moveTo(0, h * 0.74 + rise * 0.6)
      ..cubicTo(
        w * 0.35,
        h * 0.58 + rise * 0.6,
        w * 0.62,
        h * 0.86 + rise * 0.6,
        w,
        h * 0.66 + rise * 0.6,
      )
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(dune, inkPaint);
  }

  @override
  bool shouldRepaint(WaveArtwork oldDelegate) =>
      progress != oldDelegate.progress ||
      accent != oldDelegate.accent ||
      ink != oldDelegate.ink;
}
