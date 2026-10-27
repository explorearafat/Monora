import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/widgets/track_tile.dart';
import '../../data/models/library_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/player_providers.dart';

/// Starts playing [tracks] as the queue, beginning at [startFrom].
Future<void> playQueue(
  WidgetRef ref,
  List<Track> tracks, {
  Track? startFrom,
}) async {
  if (tracks.isEmpty) return;
  final player = ref.read(playerServiceProvider);
  await player.playTracks(tracks, startFrom: startFrom);
  applyPlaybackSpeed(ref);
}

/// Convenience for tapping a tile inside a list: plays the list starting at
/// the tapped track.
Future<void> playTracksStartingFrom(
  WidgetRef ref,
  List<Track> tracks,
  Track startFrom,
) => playQueue(ref, tracks, startFrom: startFrom);

/// Standard track row context menu shared by every list.
Future<void> showTrackOptions(
  BuildContext context,
  WidgetRef ref,
  Track track, {
  List<Track> surroundingQueue = const [],
}) {
  final favorites = ref.read(favoritesProvider);
  final isFavorite = favorites.contains(track.id);
  final playlists = ref.read(playlistsProvider);

  return showOptionSheet(
    context,
    title: track.title,
    subtitle: '${track.artist} · ${track.album}',
    options: [
      OptionSheetItem(
        icon: isFavorite ? Icons.heart_broken_rounded : Icons.favorite_rounded,
        label: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
        onSelected: () =>
            unawaited(ref.read(favoritesProvider.notifier).toggle(track.id)),
      ),
      OptionSheetItem(
        icon: Icons.playlist_add_rounded,
        label: 'Add to playlist…',
        onSelected: () => _pickPlaylistAndAdd(context, ref, track, playlists),
      ),
      OptionSheetItem(
        icon: Icons.queue_music_rounded,
        label: 'Play next',
        onSelected: () => _playNext(ref, track),
      ),
      OptionSheetItem(
        icon: Icons.add_to_queue_rounded,
        label: 'Add to queue',
        onSelected: () => _addToQueue(ref, track),
      ),
    ],
  );
}

Future<void> _pickPlaylistAndAdd(
  BuildContext context,
  WidgetRef ref,
  Track track,
  List<MonoraPlaylist> playlists,
) async {
  final selected = await showModalBottomSheet<MonoraPlaylist>(
    context: context,
    builder: (sheetContext) {
      final palette = sheetContext.monora;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add to playlist',
                  style: TextStyle(
                    fontFamily: 'Playfair',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: palette.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No playlists yet — create one first from the Library tab.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    color: palette.inkSecondary,
                  ),
                ),
              )
            else
              for (final playlist in playlists)
                ListTile(
                  leading: Icon(
                    Icons.queue_music_rounded,
                    color: palette.accent,
                  ),
                  title: Text(
                    playlist.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 14.5,
                      color: palette.ink,
                    ),
                  ),
                  subtitle: Text(
                    '${playlist.trackIds.length} songs',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: palette.inkSecondary,
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(playlist),
                ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
  if (selected != null) {
    await ref.read(playlistsProvider.notifier).addTrack(selected.id, track.id);
  }
}

Future<void> _playNext(WidgetRef ref, Track track) async {
  final player = ref.read(playerServiceProvider);
  final queue = player.queue;
  if (queue.isEmpty) {
    await playQueue(ref, [track]);
    return;
  }
  final current = player.currentTrack;
  final currentIndex = current == null ? -1 : queue.indexOf(current);
  final insertAt = (currentIndex + 1).clamp(0, queue.length);
  final updated = [...queue]..insert(insertAt, track);
  // Preserve the current track and its position while splicing the queue.
  final newCurrentIndex = currentIndex + (insertAt <= currentIndex ? 1 : 0);
  await player.loadQueue(
    updated,
    initialIndex: newCurrentIndex < 0 ? 0 : newCurrentIndex,
    initialPosition: player.position,
    autoplay: player.isPlaying,
  );
}

Future<void> _addToQueue(WidgetRef ref, Track track) async {
  final player = ref.read(playerServiceProvider);
  final queue = player.queue;
  if (queue.isEmpty) {
    await playQueue(ref, [track]);
    return;
  }
  final current = player.currentTrack;
  final currentIndex = current == null ? 0 : queue.indexOf(current);
  await player.loadQueue(
    [...queue, track],
    initialIndex: currentIndex < 0 ? 0 : currentIndex,
    initialPosition: player.position,
    autoplay: player.isPlaying,
  );
}

/// Favorite heart used in tiles and the player.
class FavoriteToggle extends ConsumerWidget {
  const FavoriteToggle({
    super.key,
    required this.trackId,
    this.activeColor,
    this.idleColor,
    this.size = 22,
  });

  final int trackId;
  final Color? activeColor;
  final Color? idleColor;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final isFavorite = ref.watch(
      favoritesProvider.select((ids) => ids.contains(trackId)),
    );
    return IconButton(
      onPressed: () =>
          unawaited(ref.read(favoritesProvider.notifier).toggle(trackId)),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(isFavorite),
          size: size,
          color: isFavorite ? activeColor ?? palette.heart : idleColor,
        ),
      ),
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      splashRadius: 24,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }
}
