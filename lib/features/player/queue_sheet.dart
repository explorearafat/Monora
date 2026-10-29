import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/library_models.dart';

import '../../app/theme/app_colors.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/playing_bars.dart';
import '../../providers/player_providers.dart';
import '../../services/player_service.dart';

/// Full-height queue sheet: "Now Playing" block plus the upcoming order.
/// Rows jump on tap, remove on swipe, and drag-reorder while shuffle is off.
Future<void> showQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => const QueueSheet(),
  );
}

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerServiceProvider);
    final palette = context.monora;
    final playOrder = player.playOrder;
    final currentIndex = player.currentPlayOrderIndex ?? -1;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: Column(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Queue',
                    style: TextStyle(
                      fontFamily: 'Playfair',
                      fontWeight: FontWeight.w600,
                      fontSize: 26,
                      color: palette.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, size: 24, color: palette.ink),
                  tooltip: 'Close queue',
                ),
              ],
            ),
          ),
          if (player.shuffleEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.shuffle_rounded, size: 15, color: palette.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Shuffle is on — drag to reorder is disabled.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: palette.inkTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: playOrder.isEmpty
                ? Center(
                    child: Text(
                      'Nothing queued yet',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5,
                        color: palette.inkSecondary,
                      ),
                    ),
                  )
                : _QueueList(
                    playOrder: playOrder,
                    currentIndex: currentIndex,
                    player: player,
                  ),
          ),
        ],
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({
    required this.playOrder,
    required this.currentIndex,
    required this.player,
  });

  final List<Track> playOrder;
  final int currentIndex;
  final MonoraPlayerService player;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;

    final nowPlaying = currentIndex >= 0 && currentIndex < playOrder.length
        ? playOrder[currentIndex]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nowPlaying != null) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              'Now Playing',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                letterSpacing: 0.4,
              ),
            ),
          ),
          _QueueRow(
            track: nowPlaying,
            index: currentIndex,
            positionLabel: '',
            isCurrent: true,
            reorderable: false,
            onTap: () {},
          ),
        ],
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 28, top: 4),
            itemCount: playOrder.length,
            onReorderItem: (oldIndex, newIndex) {
              unawaited(player.moveInPlayOrder(oldIndex, newIndex));
            },
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(animation.value);
                  return Transform.scale(
                    scale: 1.0 + 0.03 * t,
                    child: Material(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(18),
                      elevation: 3 * t,
                      child: child,
                    ),
                  );
                },
              );
            },
            header: const SizedBox.shrink(),
            itemBuilder: (context, index) {
              final track = playOrder[index];
              final isCurrent = index == currentIndex;
              return _QueueRow(
                key: ValueKey('q-${track.id}-$index'),
                track: track,
                index: index,
                positionLabel: '${index + 1}',
                isCurrent: isCurrent,
                reorderable: !player.shuffleEnabled,
                onTap: () => unawaited(player.playFromPlayOrder(index)),
                onRemove: () => unawaited(player.removeFromPlayOrder(index)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QueueRow extends ConsumerWidget {
  const _QueueRow({
    super.key,
    required this.track,
    required this.index,
    required this.positionLabel,
    required this.isCurrent,
    required this.reorderable,
    required this.onTap,
    this.onRemove,
  });

  final Track track;
  final int index;
  final String positionLabel;
  final bool isCurrent;
  final bool reorderable;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Dismissible(
        key: ValueKey('dismiss-${track.id}-$positionLabel'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async => onRemove != null && !isCurrent,
        onDismissed: (_) => onRemove?.call(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 28),
          decoration: BoxDecoration(
            color: palette.heart.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_outline_rounded, color: palette.heart),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isCurrent ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  if (positionLabel.isNotEmpty)
                    SizedBox(
                      width: 24,
                      child: Text(
                        positionLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: palette.inkTertiary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  ArtworkTile(
                    entityId: track.id,
                    target: ArtworkTarget.track,
                    size: 44,
                    radius: 10,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: isCurrent ? palette.accent : palette.ink,
                          ),
                        ),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 11.5,
                            color: palette.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrent) const PlayingBars(),
                  if (reorderable)
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          size: 20,
                          color: palette.inkTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return row;
  }
}
