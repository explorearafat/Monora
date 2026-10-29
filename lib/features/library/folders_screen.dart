import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/widgets/common.dart';
import '../../data/models/library_models.dart';
import '../../providers/app_providers.dart';
import '../player/player_actions.dart';
import '../shell/shell_screen.dart' show MiniPlayerBar;
import 'library_detail_screens.dart' show TrackCollectionScaffold;

/// File-system view over the library: folders that actually contain audio,
/// with only the visible track count shown per row.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final text = MonoraText.of(palette);
    final tracks = ref.watch(
      libraryProvider.select((async) => async.value?.tracks ?? const <Track>[]),
    );
    final folders = foldersFromTracks(tracks);

    return Scaffold(
      backgroundColor: palette.background,
      bottomNavigationBar: tracks.isEmpty
          ? null
          : SafeArea(top: false, child: MiniPlayerBar()),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          tooltip: 'Back',
        ),
        title: Text('Folders', style: text.screenTitle),
      ),
      body: folders.isEmpty
          ? const EmptyState(
              icon: Icons.folder_off_rounded,
              title: 'No folders yet',
              message: 'No audio folders were found on this device.',
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: folders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final folder = folders[index];
                return Pressable(
                  onTap: () => pushDetail(
                    context,
                    FolderTracksScreen(folderPath: folder.path),
                  ),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
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
                          child: Icon(
                            Icons.folder_rounded,
                            size: 21,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                folder.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.trackTitle,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${folder.trackCount} '
                                '${folder.trackCount == 1 ? 'song' : 'songs'}'
                                ' · ${folder.path}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.trackSubtitle,
                              ),
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
                );
              },
            ),
    );
  }
}

class LibraryFolder {
  const LibraryFolder({required this.path, required this.trackCount});

  final String path;
  final int trackCount;

  String get name {
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final slash = trimmed.lastIndexOf('/');
    return slash < 0 ? trimmed : trimmed.substring(slash + 1);
  }
}

List<LibraryFolder> foldersFromTracks(List<Track> tracks) {
  final counts = <String, int>{};
  for (final track in tracks) {
    final file = track.file.replaceAll('\\', '/');
    final slash = file.lastIndexOf('/');
    final folder = slash <= 0 ? '/' : file.substring(0, slash);
    counts[folder] = (counts[folder] ?? 0) + 1;
  }
  final folders = [
    for (final entry in counts.entries)
      LibraryFolder(path: entry.key, trackCount: entry.value),
  ]..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
  return folders;
}

/// All tracks inside one folder, in file-name order.
class FolderTracksScreen extends ConsumerWidget {
  const FolderTracksScreen({super.key, required this.folderPath});

  final String folderPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider).value;
    final prefix = '$folderPath/';
    final tracks = [
      for (final track in library?.tracks ?? const <Track>[])
        if (track.file.replaceAll('\\', '/').startsWith(prefix)) track,
    ]..sort(
      (a, b) => a.file.toLowerCase().compareTo(b.file.toLowerCase()),
    );
    final name = folderPath.endsWith('/')
        ? folderPath
        : folderPath.substring(folderPath.lastIndexOf('/') + 1);

    return TrackCollectionScaffold(
      title: name,
      subtitle: folderPath,
      tracks: tracks,
      emptyIcon: Icons.folder_off_rounded,
      emptyMessage: 'No playable songs remain in this folder.',
      onTrackMenu: (track) => showTrackOptions(context, ref, track),
    );
  }
}
