import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// The Monora mark: an ink disc with five rounded waveform bars, drawn with
/// [CustomPaint] so it stays crisp at any size and can be recolored.
class MonoraLogo extends StatelessWidget {
  const MonoraLogo({
    super.key,
    this.size = 48,
    this.circleColor = MonoraColors.logoInk,
    this.barColor = MonoraColors.logoBar,
  });

  final double size;
  final Color circleColor;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MonoraLogoPainter(circleColor, barColor)),
    );
  }
}

class _MonoraLogoPainter extends CustomPainter {
  const _MonoraLogoPainter(this.circleColor, this.barColor);

  final Color circleColor;
  final Color barColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    canvas.drawCircle(
      Offset(radius, radius),
      radius,
      Paint()..color = circleColor,
    );

    final barPaint = Paint()..color = barColor;
    final barWidth = size.width * 0.058;
    final barRadius = Radius.circular(barWidth / 2);
    // (center offset fraction of width, height fraction of width)
    const bars = [
      (0.0, 0.34),
      (0.115, 0.56),
      (-0.115, 0.56),
      (0.23, 0.26),
      (-0.23, 0.26),
    ];
    for (final (offsetFraction, heightFraction) in bars) {
      final centerX = radius + offsetFraction * size.width;
      final halfHeight = heightFraction * size.width / 2;
      final centerY = radius;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(centerX, centerY),
            width: barWidth,
            height: halfHeight * 2,
          ),
          barRadius,
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MonoraLogoPainter oldDelegate) =>
      circleColor != oldDelegate.circleColor ||
      barColor != oldDelegate.barColor;
}

/// Standard press feedback: a light scale-down with fade, restoring on
/// release/cancel. Wrap any tappable surface that isn't a Material button.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.scale = 0.97,
    this.borderRadius,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final double scale;

  /// Clip shape for the ripple; also the region that accepts the gesture.
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled || widget.onTap == null;
    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: AnimatedScale(
        scale: _pressed && !disabled ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed && !disabled ? 0.82 : 1,
          duration: const Duration(milliseconds: 110),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: widget.borderRadius,
            child: InkWell(
              onTap: disabled ? null : widget.onTap,
              onLongPress: widget.onLongPress,
              borderRadius: widget.borderRadius,
              onTapDown: (_) => _set(true),
              onTapUp: (_) => _set(false),
              onTapCancel: () => _set(false),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header row: serif title on the left, optional trailing action
/// ("See all") on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 12),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    final monoraText = MonoraText.of(palette);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: monoraText.sectionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null && onAction != null)
            Pressable(
              borderRadius: BorderRadius.circular(12),
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                    color: palette.inkTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reusable empty-state block used for missing music, missing lyrics, empty
/// search results, and empty playlists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 56 : 72,
              height: compact ? 56 : 72,
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 26 : 32,
                color: palette.inkTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Playfair',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13,
                height: 1.45,
                color: palette.inkSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              Pressable(
                borderRadius: BorderRadius.circular(24),
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: palette.ink,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: palette.background,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
