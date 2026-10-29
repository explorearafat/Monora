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
import '../library/library_detail_screens.dart';
import '../library/playlists_screen.dart';
import '../player/player_actions.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onOpenSearch, this.onOpenProfile});

  /// Lets the greeting's search icon jump to the Search tab.
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenProfile;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _rescan() => ref.read(libraryProvider.notifier).rescan();

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    final text = MonoraText.of(palette);
    final libraryAsync = ref.watch(libraryProvider);
    final library = libraryAsync.value ?? LibraryData.empty;
    final recents = ref.watch(recentTracksProvider);
    final playlists = ref.watch(playlistsProvider);
    List<Track> playlistTracksResolver(MonoraPlaylist playlist) =>
        ref.read(playlistTracksFamily(playlist));

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: palette.accent,
        backgroundColor: palette.surface,
        onRefresh: _rescan,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(), style: text.greeting),
                          const SizedBox(height: 2),
                          Text(
                            'Explore your favorite sounds.',
                            style: text.greetingSub,
                          ),
                        ],
                      ),
                    ),
                    Pressable(
                      onTap: widget.onOpenSearch,
                      semanticLabel: 'Search',
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.search_rounded,
                          size: 23,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    Pressable(
                      onTap: widget.onOpenProfile,
                      semanticLabel: 'Open profile',
                      borderRadius: BorderRadius.circular(21),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.accentSoft,
                          border: Border.all(color: palette.outline),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          ref
                              .watch(profileNameProvider)
                              .characters
                              .first
                              .toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: palette.accentDeep,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            if (libraryAsync.isLoading && library.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _LibraryScanState(),
              )
            else if (libraryAsync.hasError && library.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Couldn’t read your library',
                  message: 'Something went wrong while scanning. Try again in a moment.',
                  actionLabel: 'Retry',
                  onAction: () => unawaited(_rescan()),
                ),
              )
            else if (library.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyLibraryHint(),
              )
            else ...[
              SliverToBoxAdapter(
                child: _FeaturedCard(
                  playlist: playlists.isNotEmpty ? playlists.first : null,
                  library: library,
                  onOpenPlaylist: playlists.isEmpty
                      ? null
                      : () => pushDetail(
                          context,
                          PlaylistDetailScreen(playlist: playlists.first),
                        ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Recently Played',
                  actionLabel: recents.length > 4 ? 'See all' : null,
                  onAction: () => pushDetail(
                    context,
                    const TrackListScreen(
                      title: 'Recently Played',
                      mode: TrackListMode.recents,
                    ),
                  ),
                ),
              ),
              if (recents.isEmpty)
                const SliverToBoxAdapter(
                  child: _SideHint(
                    icon: Icons.history_rounded,
                    text: 'Songs you play will show up here.',
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 148,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: recents.length.clamp(0, 12),
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final track = recents[index];
                        return _RecentTile(
                          track: track,
                          onTap: () =>
                              playTracksStartingFrom(ref, recents, track),
                        );
                      },
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
              const SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Made for Monora',
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SmartCard(
                          icon: Icons.local_fire_department_rounded,
                          title: 'Most Played',
                          subtitle: 'Your all-time hits',
                          mode: TrackListMode.mostPlayed,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _SmartCard(
                          icon: Icons.all_inclusive_rounded,
                          title: 'On Repeat',
                          subtitle: 'Played 3+ times',
                          mode: TrackListMode.onRepeat,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Your Playlists',
                  actionLabel: playlists.length > 3 ? 'See all' : null,
                  onAction: () => pushDetail(context, const PlaylistsScreen()),
                ),
              ),
              if (playlists.isEmpty)
                const SliverToBoxAdapter(
                  child: _SideHint(
                    icon: Icons.queue_music_rounded,
                    text: 'Create a playlist to gather your favorites.',
                  ),
                )
              else
                SliverList.separated(
                  itemCount: playlists.length.clamp(0, 4),
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final tracks = playlistTracksResolver(playlist);
                    return _PlaylistRow(
                      playlist: playlist,
                      trackCount: tracks.length,
                      onOpen: () => pushDetail(
                        context,
                        PlaylistDetailScreen(playlist: playlist),
                      ),
                      onPlay: () => playQueue(ref, tracks),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }
}

class _FeaturedCard extends ConsumerWidget {
  const _FeaturedCard({
    required this.playlist,
    required this.library,
    this.onOpenPlaylist,
  });

  final MonoraPlaylist? playlist;
  final LibraryData library;
  final VoidCallback? onOpenPlaylist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final tracks = playlist == null
        ? library.tracks
        : ref.watch(playlistTracksFamily(playlist!));
    if (tracks.isEmpty) return const SizedBox.shrink();

    final artTrack = tracks.first;
    final totalDuration = tracks.fold<Duration>(
      Duration.zero,
      (sum, track) => sum + track.duration,
    );
    final title = playlist?.name ?? 'Shuffle All';
    final subtitle = playlist == null
        ? '${tracks.length} songs across your library'
        : '${tracks.length} songs · ${formatDurationLong(totalDuration)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Pressable(
        onTap: onOpenPlaylist,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 168,
          decoration: BoxDecoration(
            // Fixed charcoal overlay: palette.ink turns light in dark mode and
            // the cream headline over it would vanish.
            color: MonoraColors.ink,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        MonoraColors.ink.withValues(alpha: 0.92),
                        MonoraColors.ink.withValues(alpha: 0.55),
                        MonoraColors.ink.withValues(alpha: 0.15),
                      ],
                    ).createShader(bounds),
                    blendMode: BlendMode.srcOver,
                    child: ArtworkTile(
                      entityId: artTrack.id,
                      target: ArtworkTarget.track,
                      size: double.infinity,
                      radius: 0,
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Playfair',
                              fontWeight: FontWeight.w600,
                              fontSize: 22,
                              color: palette.logoBar,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              fontSize: 12.5,
                              color: palette.logoBar.withValues(alpha: 0.75),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Pressable(
                      onTap: () => playQueue(ref, tracks),
                      scale: 0.9,
                      borderRadius: BorderRadius.circular(26),
                      semanticLabel: 'Play $title',
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 30,
                          color: palette.onAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 116,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtworkTile(
              entityId: track.id,
              target: ArtworkTarget.track,
              size: 116,
              radius: 16,
            ),
            const SizedBox(height: 8),
            Text(
              track.title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: palette.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              track.artist,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 11.5,
                color: palette.inkSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.playlist,
    required this.trackCount,
    required this.onOpen,
    required this.onPlay,
  });

  final MonoraPlaylist playlist;
  final int trackCount;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Pressable(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.accent, palette.accentDeep],
                ),
              ),
              child: Icon(
                Icons.queue_music_rounded,
                color: palette.onAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: palette.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$trackCount songs',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: palette.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Pressable(
              onTap: onPlay,
              scale: 0.88,
              borderRadius: BorderRadius.circular(20),
              semanticLabel: 'Play ${playlist.name}',
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 24,
                  color: palette.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Smart-playlist card ("Most Played"/"On Repeat") derived from real
/// listening data; opens the matching track list.
class _SmartCard extends ConsumerWidget {
  const _SmartCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.mode,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final TrackListMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final tracks = _smartTracks(ref, mode);
    return Pressable(
      onTap: tracks.isEmpty
          ? null
          : () => pushDetail(
              context,
              TrackListScreen(
                title: title,
                mode: mode,
              ),
            ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: palette.accent),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Playfair',
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tracks.isEmpty ? 'Nothing yet' : '${tracks.length} songs · $subtitle',
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
    );
  }

  static List<Track> _smartTracks(WidgetRef ref, TrackListMode mode) {
    final library = ref.watch(libraryProvider).value;
    final playCounts = ref.watch(playCountsProvider);
    final all = library?.tracks ?? const <Track>[];
    return switch (mode) {
      TrackListMode.mostPlayed => [
        for (final track in all)
          if ((playCounts[track.id] ?? 0) > 0) track,
      ]..sort(
        (a, b) => (playCounts[b.id] ?? 0).compareTo(playCounts[a.id] ?? 0),
      ),
      TrackListMode.onRepeat => [
        for (final track in all)
          if ((playCounts[track.id] ?? 0) >= 3) track,
      ]..sort(
        (a, b) => (playCounts[b.id] ?? 0).compareTo(playCounts[a.id] ?? 0),
      ),
      _ => const <Track>[],
    };
  }
}

class _SideHint extends StatelessWidget {
  const _SideHint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: palette.inkTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 13,
                color: palette.inkTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryScanState extends StatelessWidget {
  const _LibraryScanState();

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              valueColor: AlwaysStoppedAnimation(palette.accent),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Scanning your library…',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
              color: palette.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibraryHint extends ConsumerWidget {
  const _EmptyLibraryHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EmptyState(
      icon: Icons.music_off_rounded,
      title: 'No music found',
      message: 'Monora couldn’t find any audio files on this device. Pull down to rescan, or copy some songs over first.',
      actionLabel: 'Rescan',
      onAction: () => unawaited(ref.read(libraryProvider.notifier).rescan()),
    );
  }
}
