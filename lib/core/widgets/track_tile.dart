import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/library_models.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../utils/formatters.dart';
import 'artwork.dart';
import 'common.dart';
import 'playing_bars.dart';

/// A song row used everywhere lists of tracks appear: artwork, title +
/// artist, optional trailing slot. The row for the track that is actually
/// loaded in the player is highlighted and carries a live equalizer that
/// animates only while playback is active.
class TrackTile extends ConsumerWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.trailing,
    this.leading,
    this.isCurrent = false,
    this.showDuration = false,
  });

  final Track track;
  final VoidCallback onTap;
  final Widget? trailing;
  final Widget? leading;
  final bool isCurrent;
  final bool showDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final text = MonoraText.of(palette);

    return Padding(
      // Keep the highlight inset so it reads as a pill on the paper background.
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isCurrent ? palette.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Pressable(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (leading != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: leading!,
                  )
                else
                  ArtworkTile(
                    entityId: track.id,
                    target: ArtworkTarget.track,
                    size: 48,
                    radius: 10,
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: text.trackTitle.copyWith(
                          color: isCurrent ? palette.accent : palette.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        style: text.trackSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isCurrent) ...[
                  // Live equalizer for the track the player has loaded; the
                  // frozen (paused) bars keep the row identifiable even when
                  // a trailing action button is present.
                  const SizedBox(
                    width: 44,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: PlayingBars(),
                    ),
                  ),
                  ?trailing,
                ] else if (trailing != null)
                  trailing!
                else if (showDuration && track.duration > Duration.zero)
                  Text(
                    formatDuration(track.duration),
                    style: text.metaTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon button used as trailing action inside tiles.
class TileIconButton extends StatelessWidget {
  const TileIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.tooltip,
    this.size = 20,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final String? tooltip;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: size, color: color ?? palette.inkTertiary),
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      tooltip: tooltip ?? semanticLabel,
      splashRadius: 22,
    );
  }
}

/// Generic "more" sheet shown for tracks, albums, artists, and playlists.
/// Options are concrete (title, icon, callback) so nothing in the sheet is a
/// dead end.
class OptionSheetItem {
  const OptionSheetItem({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool destructive;
}

Future<void> showOptionSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<OptionSheetItem> options,
}) {
  final palette = context.monora;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Playfair',
                      fontWeight: FontWeight.w600,
                      fontSize: 19,
                      color: palette.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 12.5,
                          color: palette.inkSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            for (final option in options)
              Pressable(
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  option.onSelected();
                },
                borderRadius: BorderRadius.circular(0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        option.icon,
                        size: 21,
                        color: option.destructive
                            ? palette.heart
                            : palette.inkSecondary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 14.5,
                            color: option.destructive
                                ? palette.heart
                                : palette.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}
