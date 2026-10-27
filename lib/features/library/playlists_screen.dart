import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/track_tile.dart';
import '../../data/models/library_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/player_providers.dart';
import 'library_detail_screens.dart';

/// User playlists: create, rename, delete, open. Embedded in the Library
/// Playlists tab and used standalone via "See all".
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          tooltip: 'Back',
        ),
        title: Text('Playlists', style: MonoraText.of(palette).screenTitle),
      ),
      body: const PlaylistsView(),
    );
  }
}

class PlaylistsView extends ConsumerWidget {
  const PlaylistsView({
    super.key,
    this.padding = const EdgeInsets.only(bottom: 24),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final playlists = ref.watch(playlistsProvider);

    return RefreshIndicator(
      color: palette.accent,
      backgroundColor: palette.surface,
      onRefresh: () => ref.read(libraryProvider.notifier).rescan(),
      child: playlists.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.5,
                  child: EmptyState(
                    icon: Icons.queue_music_rounded,
                    title: 'No playlists yet',
                    message: 'Gather songs into collections that match your mood. Create your first one below.',
                    actionLabel: 'New Playlist',
                    onAction: () => unawaited(_createPlaylist(context, ref)),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding.add(const EdgeInsets.only(top: 6)),
              itemCount: playlists.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                if (index == playlists.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _AddPlaylistRow(
                      onTap: () => unawaited(_createPlaylist(context, ref)),
                    ),
                  );
                }
                final playlist = playlists[index];
                return _PlaylistTile(
                  playlist: playlist,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlaylistDetailScreen(playlist: playlist),
                    ),
                  ),
                  onMenu: () => _playlistMenu(context, ref, playlist),
                );
              },
            ),
    );
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.monora;
        return AlertDialog(
          title: const Text('New playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 40,
            style: TextStyle(color: palette.ink, fontFamily: 'Inter'),
            decoration: const InputDecoration(hintText: 'Playlist name'),
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
              child: Text('Create', style: TextStyle(color: palette.accent)),
            ),
          ],
        );
      },
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(playlistsProvider.notifier).create(name);
    }
  }

  Future<void> _playlistMenu(
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
          icon: Icons.play_arrow_rounded,
          label: 'Play',
          onSelected: () async {
            final tracks = ref.read(playlistTracksFamily(playlist));
            if (tracks.isNotEmpty) {
              await ref.read(playerServiceProvider).playTracks(tracks);
            }
          },
        ),
        OptionSheetItem(
          icon: Icons.drive_file_rename_outline_rounded,
          label: 'Rename',
          onSelected: () async {
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
                    onSubmitted: (value) =>
                        Navigator.of(dialogContext).pop(value),
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
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(controller.text),
                      child: Text(
                        'Save',
                        style: TextStyle(color: palette.accent),
                      ),
                    ),
                  ],
                );
              },
            );
            if (name != null && name.trim().isNotEmpty) {
              await ref
                  .read(playlistsProvider.notifier)
                  .rename(playlist.id, name);
            }
          },
        ),
        OptionSheetItem(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          destructive: true,
          onSelected: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                final palette = dialogContext.monora;
                return AlertDialog(
                  title: Text('Delete "${playlist.name}"?'),
                  content: Text(
                    'The playlist will be removed. Your songs stay in your library.',
                  ),
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
                      child: Text(
                        'Delete',
                        style: TextStyle(color: palette.heart),
                      ),
                    ),
                  ],
                );
              },
            );
            if (confirmed ?? false) {
              await ref.read(playlistsProvider.notifier).delete(playlist.id);
            }
          },
        ),
      ],
    );
  }
}

class _PlaylistTile extends ConsumerWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.onOpen,
    required this.onMenu,
  });

  final MonoraPlaylist playlist;
  final VoidCallback onOpen;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final tracks = ref.watch(playlistTracksFamily(playlist));
    final subtitle = tracks.isEmpty
        ? 'Empty'
        : '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}';

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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
            IconButton(
              onPressed: onMenu,
              icon: Icon(Icons.more_vert_rounded, color: palette.inkTertiary),
              tooltip: 'Options',
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPlaylistRow extends StatelessWidget {
  const _AddPlaylistRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Pressable(
      onTap: onTap,
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
              child: Icon(Icons.add_rounded, size: 22, color: palette.ink),
            ),
            const SizedBox(width: 14),
            Text(
              'New Playlist',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
                color: palette.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
