import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/library_models.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/common.dart';
import '../../providers/app_providers.dart';
import '../player/player_actions.dart';
import 'library_detail_screens.dart';
import 'playlists_screen.dart';

/// The "Songs" tab of the Library: quick-link rows into each collection,
/// exactly as designed.
class SongsQuickLinksView extends ConsumerWidget {
  const SongsQuickLinksView({super.key, this.onCreatePlaylist});

  final VoidCallback? onCreatePlaylist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final text = MonoraText.of(palette);
    final library = ref.watch(libraryProvider).value;
    final favoritesCount = ref.watch(favoritesProvider).length;
    final playlists = ref.watch(playlistsProvider);

    final links = <_QuickLink>[
      _QuickLink(
        icon: Icons.music_note_rounded,
        label: 'All Songs',
        detail:
            '${library?.tracks.length ?? 0} ${library?.tracks.length == 1 ? 'song' : 'songs'}',
        onTap: () => pushDetail(
          context,
          const TrackListScreen(
            title: 'All Songs',
            mode: TrackListMode.allSongs,
          ),
        ),
      ),
      _QuickLink(
        icon: Icons.album_rounded,
        label: 'Albums',
        detail:
            '${library?.albums.length ?? 0} ${library?.albums.length == 1 ? 'album' : 'albums'}',
        onTap: () => pushDetail(context, const AlbumsScreen()),
      ),
      _QuickLink(
        icon: Icons.people_alt_rounded,
        label: 'Artists',
        detail:
            '${library?.artists.length ?? 0} ${library?.artists.length == 1 ? 'artist' : 'artists'}',
        onTap: () => pushDetail(context, const ArtistsScreen()),
      ),
      _QuickLink(
        icon: Icons.queue_music_rounded,
        label: 'Playlists',
        detail:
            '${playlists.length} ${playlists.length == 1 ? 'playlist' : 'playlists'}',
        onTap: () => pushDetail(context, const PlaylistsScreen()),
      ),
      _QuickLink(
        icon: Icons.favorite_rounded,
        label: 'Favorites',
        detail:
            '$favoritesCount ${favoritesCount == 1 ? 'liked song' : 'liked songs'}',
        onTap: () => pushDetail(
          context,
          const TrackListScreen(
            title: 'Favorites',
            mode: TrackListMode.favorites,
          ),
        ),
      ),
    ];

    return Column(
      children: [
        for (final link in links)
          Pressable(
            onTap: link.onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: palette.outline),
                    ),
                    child: Icon(link.icon, size: 21, color: palette.ink),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(link.label, style: text.trackTitle),
                        const SizedBox(height: 2),
                        Text(link.detail, style: text.trackSubtitle),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: palette.inkTertiary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickLink {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
}

/// Reusable albums list (Library tab + standalone screen).
class AlbumsView extends ConsumerWidget {
  const AlbumsView({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(
      libraryProvider.select((async) => async.value?.albums ?? const <Album>[]),
    );
    if (albums.isEmpty) {
      return const _CollectionEmpty(
        icon: Icons.album_rounded,
        message: 'No albums found on this device.',
      );
    }
    return ListView.separated(
      padding: padding,
      itemCount: albums.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final album = albums[index];
        return Pressable(
          onTap: () =>
              pushDetail(context, AlbumDetailScreen(albumId: album.id)),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                ArtworkTile(
                  entityId: album.id,
                  target: ArtworkTarget.album,
                  size: 52,
                  radius: 12,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: context.monora.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${album.artist} · ${album.trackCount} songs',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: context.monora.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: context.monora.inkTertiary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Reusable artists list (Library tab + standalone screen).
class ArtistsView extends ConsumerWidget {
  const ArtistsView({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(
      libraryProvider.select(
        (async) => async.value?.artists ?? const <Artist>[],
      ),
    );
    if (artists.isEmpty) {
      return const _CollectionEmpty(
        icon: Icons.people_alt_rounded,
        message: 'No artists found on this device.',
      );
    }
    return ListView.separated(
      padding: padding,
      itemCount: artists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final artist = artists[index];
        return Pressable(
          onTap: () =>
              pushDetail(context, ArtistDetailScreen(artistId: artist.id)),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                ArtistAvatar(name: artist.name, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: context.monora.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${artist.trackCount} songs · ${artist.albumCount} albums',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: context.monora.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: context.monora.inkTertiary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CollectionEmpty extends StatelessWidget {
  const _CollectionEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(icon: icon, title: 'Nothing here yet', message: message);
  }
}

/// Shared header (used by standalone collection screens).
class CollectionScreenScaffold extends StatelessWidget {
  const CollectionScreenScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(title, style: MonoraText.of(palette).screenTitle),
        leading: const _BackChevron(),
      ),
      body: child,
    );
  }
}

class _BackChevron extends StatelessWidget {
  const _BackChevron();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.chevron_left_rounded, size: 28),
      tooltip: 'Back',
    );
  }
}

/// Resolves the tracks of an album/artist lazily without blocking the list.
Future<List<Track>> tracksForAlbum(WidgetRef ref, int albumId) async {
  final tracks = await ref.read(libraryProvider.future);
  return tracks.tracks
      .where((track) => track.albumId == albumId)
      .toList(growable: false);
}

Future<List<Track>> tracksForArtist(WidgetRef ref, int artistId) async {
  final tracks = await ref.read(libraryProvider.future);
  return tracks.tracks
      .where((track) => track.artistId == artistId)
      .toList(growable: false);
}

/// Formats total playlist/album length for subtitles.
String totalDurationLabel(List<Track> tracks) => formatDurationLong(
  tracks.fold<Duration>(Duration.zero, (sum, track) => sum + track.duration),
);

/// Plays the given collection with shuffle applied for shuffle buttons.
Future<void> playShuffled(WidgetRef ref, List<Track> tracks) async {
  if (tracks.isEmpty) return;
  final shuffled = [...tracks]..shuffle();
  await playQueue(ref, shuffled, startFrom: shuffled.first);
}
