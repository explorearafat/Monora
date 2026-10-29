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
import '../../core/widgets/track_tile.dart';
import '../../providers/app_providers.dart';
import '../../providers/player_providers.dart';
import '../library/library_detail_screens.dart';
import '../player/player_actions.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    final text = MonoraText.of(palette);
    final library = ref.watch(libraryProvider).value;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Text('Search', style: text.screenTitle),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: palette.ink,
              ),
              cursorColor: palette.accent,
              decoration: InputDecoration(
                hintText: 'Search songs, artists, albums…',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 13.5,
                  color: palette.inkTertiary,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: palette.inkTertiary,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: palette.inkSecondary,
                        ),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
                filled: true,
                fillColor: palette.surfaceAlt.withValues(alpha: 0.55),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: library == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _query.trim().isEmpty
                ? _TrendingView(library: library)
                : _ResultsView(library: library, query: _query),
          ),
        ],
      ),
    );
  }
}

/// Default state while the query is empty: trending picks derived from
/// listening history (falls back to library composition).
class _TrendingView extends ConsumerWidget {
  const _TrendingView({required this.library});

  final LibraryData library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final trending = ref.watch(trendingProvider);

    if (library.isEmpty) {
      return EmptyState(
        icon: Icons.music_note_rounded,
        title: 'Your library is empty',
        message: 'Add music to this device and it will show up here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        if (trending.artists.isNotEmpty) ...[
          const SectionHeader(
            title: 'Trending artists',
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
          ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: trending.artists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final artist = trending.artists[index];
                return Pressable(
                  onTap: () => pushDetail(
                    context,
                    ArtistDetailScreen(artistId: artist.id),
                  ),
                  borderRadius: BorderRadius.circular(32),
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        ArtistAvatar(name: artist.name, size: 64),
                        const SizedBox(height: 6),
                        Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            color: palette.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (trending.songs.isNotEmpty) ...[
          const SectionHeader(
            title: 'Trending songs',
            padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
          ),
          for (final track in trending.songs)
            TrackTile(
              track: track,
              isCurrent:
                  ref.watch(
                    playerServiceProvider.select(
                      (player) => player.currentTrack?.id,
                    ),
                  ) ==
                  track.id,
              onTap: () =>
                  unawaited(playTracksStartingFrom(ref, trending.songs, track)),
              trailing: TileIconButton(
                icon: Icons.more_vert_rounded,
                semanticLabel: 'More options',
                onTap: () => showTrackOptions(context, ref, track),
              ),
            ),
        ],
      ],
    );
  }
}

/// Live results for the active query.
class _ResultsView extends ConsumerWidget {
  const _ResultsView({required this.library, required this.query});

  final LibraryData library;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final result = searchLibrary(library, query);

    if (result.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches for “$query”',
        message: 'Check the spelling or try a shorter query.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        if (result.artists.isNotEmpty) ...[
          const SectionHeader(
            title: 'Artists',
            padding: EdgeInsets.fromLTRB(20, 4, 20, 6),
          ),
          for (final artist in result.artists.take(4))
            Pressable(
              onTap: () =>
                  pushDetail(context, ArtistDetailScreen(artistId: artist.id)),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    ArtistAvatar(name: artist.name, size: 46),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${artist.trackCount} songs',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: palette.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
        ],
        if (result.albums.isNotEmpty) ...[
          const SectionHeader(
            title: 'Albums',
            padding: EdgeInsets.fromLTRB(20, 4, 20, 6),
          ),
          for (final album in result.albums.take(4))
            Pressable(
              onTap: () =>
                  pushDetail(context, AlbumDetailScreen(albumId: album.id)),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    ArtworkTile(
                      entityId: album.id,
                      target: ArtworkTarget.album,
                      size: 46,
                      radius: 10,
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
                              fontSize: 14,
                              color: palette.ink,
                            ),
                          ),
                          Text(
                            album.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: palette.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${album.trackCount} songs',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: palette.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
        ],
        if (result.songs.isNotEmpty) ...[
          const SectionHeader(
            title: 'Songs',
            padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
          ),
          for (final track in result.songs)
            TrackTile(
              track: track,
              showDuration: true,
              isCurrent:
                  ref.watch(
                    playerServiceProvider.select(
                      (player) => player.currentTrack?.id,
                    ),
                  ) ==
                  track.id,
              onTap: () =>
                  unawaited(playTracksStartingFrom(ref, result.songs, track)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (track.duration > Duration.zero)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        formatDuration(track.duration),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: palette.inkTertiary,
                        ),
                      ),
                    ),
                  TileIconButton(
                    icon: Icons.more_vert_rounded,
                    semanticLabel: 'More options',
                    onTap: () => showTrackOptions(context, ref, track),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
