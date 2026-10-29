import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/widgets/common.dart';
import '../../providers/app_providers.dart';
import 'library_views.dart';
import 'playlists_screen.dart';

/// The Library tab: serif header, segmented pills (Songs / Albums / Artists /
/// Playlists), a search field that jumps to the Search tab, and the tab
/// content.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.onOpenSearch});

  final VoidCallback? onOpenSearch;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _tab = 0;

  static const _tabs = ['Songs', 'Albums', 'Artists', 'Playlists'];

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    final text = MonoraText.of(palette);
    final libraryAsync = ref.watch(libraryProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Expanded(child: Text('Library', style: text.screenTitle)),
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
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = _tab == index;
                return Pressable(
                  onTap: () => setState(() => _tab = index),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // Fixed charcoal/cream pair: both flip with the theme,
                      // which would leave the selected label unreadable.
                      color: selected ? MonoraColors.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: selected
                          ? null
                          : Border.all(color: palette.outline),
                    ),
                    child: Text(
                      _tabs[index],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: selected
                            ? MonoraColors.logoBar
                            : palette.inkSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Pressable(
              onTap: widget.onOpenSearch,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: palette.inkTertiary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Search your music…',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 13.5,
                        color: palette.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child:
                libraryAsync.isLoading &&
                    (libraryAsync.value == null || libraryAsync.value!.isEmpty)
                ? Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(palette.accent),
                      ),
                    ),
                  )
                : _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: switch (_tab) {
        0 => SongsQuickLinksView(
          key: const ValueKey('songs'),
          onCreatePlaylist: null,
        ),
        1 => const AlbumsView(
          key: ValueKey('albums'),
          padding: EdgeInsets.only(bottom: 16),
        ),
        2 => const ArtistsView(
          key: ValueKey('artists'),
          padding: EdgeInsets.only(bottom: 16),
        ),
        _ => PlaylistsView(
          key: const ValueKey('playlists'),
          padding: const EdgeInsets.only(top: 2),
        ),
      },
    );
  }
}
