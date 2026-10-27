import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/library_models.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/track_tile.dart';
import '../../providers/app_providers.dart';
import '../../providers/player_providers.dart';
import '../player/player_actions.dart';
import 'library_views.dart';

enum TrackListMode { allSongs, favorites, recents }

/// A generic track-list screen used for All Songs, Favorites, and Recently
/// Played — a hero header, metadata line, play/shuffle actions, and the list.
class TrackListScreen extends ConsumerWidget {
  const TrackListScreen({super.key, required this.title, required this.mode});

  final String title;
  final TrackListMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider).value;
    final favorites = ref.watch(favoritesProvider);
    final recents = ref.watch(recentTracksProvider);

    final List<Track> tracks = switch (mode) {
      TrackListMode.allSongs => library?.tracks ?? const [],
      TrackListMode.favorites => [
        if (library != null)
          for (final track in library.tracks)
            if (favorites.contains(track.id)) track,
      ],
      TrackListMode.recents => recents,
    };

    return _TrackCollectionScaffold(
      title: title,
      tracks: tracks,
      emptyIcon: mode == TrackListMode.favorites
          ? Icons.favorite_border_rounded
          : mode == TrackListMode.recents
          ? Icons.history_rounded
          : Icons.music_off_rounded,
      emptyMessage: switch (mode) {
        TrackListMode.allSongs =>
          'No audio files were found on this device yet.',
        TrackListMode.favorites =>
          'Tap the heart on any song to keep it close.',
        TrackListMode.recents => 'Songs you play will appear here.',
      },
    );
  }
}

/// Shared scaffold for screens that present a play-able list of tracks.
class _TrackCollectionScaffold extends ConsumerWidget {
  const _TrackCollectionScaffold({
    required this.title,
    required this.tracks,
    required this.emptyIcon,
    required this.emptyMessage,
    this.subtitle,
    this.headerBuilder,
    this.headerHeroTag,
    this.onTrackMenu,
  });

  final String title;
  final List<Track> tracks;
  final IconData emptyIcon;
  final String emptyMessage;
  final String? subtitle;
  final WidgetBuilder? headerBuilder;
  final String? headerHeroTag;
  final void Function(Track track)? onTrackMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final text = MonoraText.of(palette);
    final currentTrack = ref.watch(
      playerServiceProvider.select((player) => player.currentTrack),
    );

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          tooltip: 'Back',
        ),
        title: Text(title, style: text.screenTitle),
      ),
      body: tracks.isEmpty
          ? EmptyState(
              icon: emptyIcon,
              title: 'Nothing here yet',
              message: emptyMessage,
            )
          : Column(
              children: [
                if (headerBuilder != null) headerBuilder!(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle ??
                              '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'} · ${totalDurationLabel(tracks)}',
                          style: text.trackSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...[
                        _CircleAction(
                          icon: Icons.shuffle_rounded,
                          semanticLabel: 'Shuffle play',
                          onTap: () => unawaited(playShuffled(ref, tracks)),
                        ),
                        const SizedBox(width: 10),
                        _CircleAction(
                          icon: Icons.play_arrow_rounded,
                          filled: true,
                          semanticLabel: 'Play all',
                          onTap: () => unawaited(
                            playQueue(ref, tracks, startFrom: tracks.first),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: tracks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return TrackTile(
                        track: track,
                        isCurrent: currentTrack?.id == track.id,
                        showDuration: onTrackMenu == null,
                        onTap: () => unawaited(
                          playTracksStartingFrom(ref, tracks, track),
                        ),
                        trailing: onTrackMenu != null
                            ? TileIconButton(
                                icon: Icons.more_vert_rounded,
                                semanticLabel: 'More options',
                                onTap: () => onTrackMenu!(track),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      borderRadius: BorderRadius.circular(24),
      semanticLabel: semanticLabel,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: filled ? palette.ink : palette.surface,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: palette.outline),
        ),
        child: Icon(
          icon,
          size: 22,
          color: filled ? palette.logoBar : palette.ink,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Albums
// ---------------------------------------------------------------------------

class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CollectionScreenScaffold(
      title: 'Albums',
      child: const AlbumsView(padding: EdgeInsets.only(bottom: 24)),
    );
  }
}

class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.albumId});

  final int albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider).value;
    final album = library?.albums.where((a) => a.id == albumId).firstOrNull;
    final tracks = library == null
        ? const <Track>[]
        : library.tracks
              .where((track) => track.albumId == albumId)
              .toList(growable: false);

    if (album == null) {
      return const CollectionScreenScaffold(
        title: 'Album',
        child: EmptyState(
          icon: Icons.album_rounded,
          title: 'Album unavailable',
          message: 'This album is no longer in your library.',
        ),
      );
    }

    return _TrackCollectionScaffold(
      title: album.name,
      subtitle:
          '${album.artist} · ${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}',
      tracks: tracks,
      emptyIcon: Icons.album_rounded,
      emptyMessage: 'No playable songs remain in this album.',
      headerBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
        child: Center(
          child: Hero(
            tag: 'album-art-$albumId',
            child: ArtworkTile(
              entityId: album.id,
              target: ArtworkTarget.album,
              size: 168,
              radius: 20,
            ),
          ),
        ),
      ),
      headerHeroTag: 'album-art-$albumId',
      onTrackMenu: (track) => showTrackOptions(context, ref, track),
    );
  }
}

// ---------------------------------------------------------------------------
// Artists
// ---------------------------------------------------------------------------

class ArtistsScreen extends StatelessWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CollectionScreenScaffold(
      title: 'Artists',
      child: const ArtistsView(padding: EdgeInsets.only(bottom: 24)),
    );
  }
}

class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.artistId});

  final int artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider).value;
    final artist = library?.artists.where((a) => a.id == artistId).firstOrNull;
    final tracks = library == null
        ? const <Track>[]
        : library.tracks
              .where((track) => track.artistId == artistId)
              .toList(growable: false);

    if (artist == null) {
      return const CollectionScreenScaffold(
        title: 'Artist',
        child: EmptyState(
          icon: Icons.person_off_rounded,
          title: 'Artist unavailable',
          message: 'This artist is no longer in your library.',
        ),
      );
    }

    return _TrackCollectionScaffold(
      title: artist.name,
      subtitle:
          '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'} · ${artist.albumCount} ${artist.albumCount == 1 ? 'album' : 'albums'}',
      tracks: tracks,
      emptyIcon: Icons.person_off_rounded,
      emptyMessage: 'No playable songs remain for this artist.',
      headerBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
        child: Center(child: ArtistAvatar(name: artist.name, size: 120)),
      ),
      onTrackMenu: (track) => showTrackOptions(context, ref, track),
    );
  }
}

// ---------------------------------------------------------------------------
// Playlist detail
// ---------------------------------------------------------------------------

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlist});

  final MonoraPlaylist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final tracks = ref.watch(playlistTracksFamily(playlist));
    final text = MonoraText.of(palette);

    if (tracks.isEmpty) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
          ),
          title: Text(playlist.name, style: text.screenTitle),
        ),
        body: EmptyState(
          icon: Icons.queue_music_rounded,
          title: 'This playlist is empty',
          message:
              'Add songs from any list via the ⋮ menu, then they’ll live here.',
        ),
      );
    }

    return _TrackCollectionScaffold(
      title: playlist.name,
      subtitle:
          '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'} · ${totalDurationLabel(tracks)}',
      tracks: tracks,
      emptyIcon: Icons.queue_music_rounded,
      emptyMessage: '',
      headerBuilder: (context) =>
          _PlaylistHeader(playlist: playlist, trackCount: tracks.length),
      onTrackMenu: (track) =>
          showPlaylistTrackOptions(context, ref, playlist, track),
    );
  }
}

class _PlaylistHeader extends ConsumerWidget {
  const _PlaylistHeader({required this.playlist, required this.trackCount});

  final MonoraPlaylist playlist;
  final int trackCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final text = MonoraText.of(palette);
    final tracks = ref.watch(playlistTracksFamily(playlist));
    final artTrack = tracks.isNotEmpty ? tracks.first : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.accent, palette.accentDeep, palette.ink],
                ),
              ),
              child: artTrack == null
                  ? Icon(
                      Icons.queue_music_rounded,
                      size: 52,
                      color: palette.onAccent.withValues(alpha: 0.9),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: ArtworkTile(
                        entityId: artTrack.id,
                        target: ArtworkTarget.track,
                        size: 168,
                        radius: 22,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            playlist.name,
            style: text.screenTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$trackCount ${trackCount == 1 ? 'song' : 'songs'}',
            style: text.trackSubtitle,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleAction(
                icon: Icons.shuffle_rounded,
                semanticLabel: 'Shuffle playlist',
                onTap: () => unawaited(playShuffled(ref, tracks)),
              ),
              const SizedBox(width: 12),
              _CircleAction(
                icon: Icons.play_arrow_rounded,
                filled: true,
                semanticLabel: 'Play playlist',
                onTap: () =>
                    unawaited(playQueue(ref, tracks, startFrom: tracks.first)),
              ),
              const SizedBox(width: 12),
              _CircleAction(
                icon: Icons.more_horiz_rounded,
                semanticLabel: 'Playlist options',
                onTap: () => showPlaylistOptions(context, ref, playlist),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Options sheet for the playlist itself.
Future<void> showPlaylistOptions(
  BuildContext context,
  WidgetRef ref,
  MonoraPlaylist playlist,
) {
  return showOptionSheet(
    context,
    title: playlist.name,
    subtitle: '${playlist.trackIds.length} songs',
    options: [
      OptionSheetItem(
        icon: Icons.drive_file_rename_outline_rounded,
        label: 'Rename playlist',
        onSelected: () => _renamePlaylist(context, ref, playlist),
      ),
      OptionSheetItem(
        icon: Icons.delete_outline_rounded,
        label: 'Delete playlist',
        destructive: true,
        onSelected: () async {
          final confirmed = await _confirmDestructive(
            context,
            title: 'Delete "${playlist.name}"?',
            message: 'The playlist will be removed. Your songs stay in your library.',
          );
          if (confirmed) {
            await ref.read(playlistsProvider.notifier).delete(playlist.id);
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
        },
      ),
    ],
  );
}

/// Options sheet for a track inside a playlist (adds the remove action).
Future<void> showPlaylistTrackOptions(
  BuildContext context,
  WidgetRef ref,
  MonoraPlaylist playlist,
  Track track,
) {
  return showOptionSheet(
    context,
    title: track.title,
    subtitle: '${track.artist} · ${track.album}',
    options: [
      OptionSheetItem(
        icon: Icons.play_arrow_rounded,
        label: 'Play from here',
        onSelected: () async {
          final tracks = ref.read(playlistTracksFamily(playlist));
          final index = tracks.indexOf(track);
          if (index >= 0) {
            await playQueue(ref, tracks, startFrom: track);
          }
        },
      ),
      OptionSheetItem(
        icon: Icons.playlist_add_rounded,
        label: 'Add to another playlist…',
        onSelected: () => showTrackOptions(context, ref, track),
      ),
      OptionSheetItem(
        icon: Icons.remove_circle_outline_rounded,
        label: 'Remove from this playlist',
        destructive: true,
        onSelected: () => unawaited(
          ref
              .read(playlistsProvider.notifier)
              .removeTrack(playlist.id, track.id),
        ),
      ),
    ],
  );
}

Future<void> _renamePlaylist(
  BuildContext context,
  WidgetRef ref,
  MonoraPlaylist playlist,
) async {
  final controller = TextEditingController(text: playlist.name);
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final palette = dialogContext.monora;
      return AlertDialog(
        title: const Text('Rename playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          style: TextStyle(color: palette.ink, fontFamily: 'Inter'),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            counterStyle: TextStyle(color: palette.inkTertiary),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: palette.inkSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text('Save', style: TextStyle(color: palette.accent)),
          ),
        ],
      );
    },
  );
  if (name != null && name.trim().isNotEmpty) {
    await ref.read(playlistsProvider.notifier).rename(playlist.id, name);
  }
}

Future<bool> _confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final palette = dialogContext.monora;
      return AlertDialog(
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Playfair',
            fontWeight: FontWeight.w600,
            fontSize: 19,
            color: palette.ink,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: palette.inkSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Delete', style: TextStyle(color: palette.heart)),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
