import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../data/models/library_models.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/common.dart';
import '../../providers/app_providers.dart';
import '../../providers/player_providers.dart';
import '../../services/player_service.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../player/now_playing_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';

/// Hosts the four bottom tabs, the mini-player, and playback side effects
/// (recent plays, play counts, failure toasts).
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _index = 0;
  int? _lastRecordedTrackId;
  StreamSubscription<PlaybackFailure>? _failureSub;

  MonoraPlayerService get _player => ref.read(playerServiceProvider);

  @override
  void initState() {
    super.initState();
    _player.addListener(_onPlayerChanged);
    _failureSub = _player.failureStream.listen(
      (failure) => _showFailure(failure.message),
    );
  }

  @override
  void dispose() {
    _failureSub?.cancel();
    _player.removeListener(_onPlayerChanged);
    super.dispose();
  }

  void _onPlayerChanged() {
    final track = _player.currentTrack;
    final id = track?.id;
    if (id != null && id != _lastRecordedTrackId) {
      _lastRecordedTrackId = id;
      unawaited(ref.read(recentsProvider.notifier).record(id));
      unawaited(ref.read(playCountsProvider.notifier).increment(id));
    }
  }

  void _showFailure(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectTab(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Scaffold(
      backgroundColor: palette.background,
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          LibraryScreen(),
          SearchScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayerBar(),
          _MonoraNavBar(index: _index, onSelect: _selectTab),
        ],
      ),
    );
  }
}

class _MonoraNavBar extends StatelessWidget {
  const _MonoraNavBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _items = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.library_music_outlined, Icons.library_music_rounded, 'Library'),
    (Icons.search_outlined, Icons.search_rounded, 'Search'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(top: BorderSide(color: palette.outline, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    iconData: _items[i].$1,
                    activeIconData: _items[i].$2,
                    label: _items[i].$3,
                    selected: index == i,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.iconData,
    required this.activeIconData,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData iconData;
  final IconData activeIconData;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    final color = selected ? palette.ink : palette.inkTertiary;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        scale: 0.94,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: MonoraMotion.fast,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                selected ? activeIconData : iconData,
                key: ValueKey(selected),
                size: 23,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim bar above the navigation showing the current track; expands into the
/// full Now Playing screen when tapped.
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerServiceProvider);
    final palette = context.monora;
    final track = player.currentTrack;

    return AnimatedSlideAndFade(
      visible: track != null,
      child: track == null
          ? const SizedBox.shrink()
          : Pressable(
              borderRadius: BorderRadius.circular(0),
              onTap: () => pushImmersive(
                context,
                NowPlayingScreen(heroTag: 'mini-art-${track.id}'),
              ),
              child: Material(
                color: palette.surface,
                elevation: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                      child: Row(
                        children: [
                          ArtworkTile(
                            entityId: track.id,
                            target: ArtworkTarget.track,
                            size: 44,
                            radius: 10,
                            heroTag: 'mini-art-${track.id}',
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
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
                          _MiniControlButton(
                            icon: player.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            semanticLabel: player.isPlaying ? 'Pause' : 'Play',
                            onTap: () => unawaited(player.playPause()),
                          ),
                          _MiniControlButton(
                            icon: Icons.skip_next_rounded,
                            semanticLabel: 'Next track',
                            onTap: () => unawaited(player.next()),
                          ),
                        ],
                      ),
                    ),
                    const _MiniProgressHairline(),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Collapses/expands the mini-player smoothly when a track starts/stops.
class AnimatedSlideAndFade extends StatelessWidget {
  const AnimatedSlideAndFade({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MonoraMotion.normal,
      switchInCurve: MonoraMotion.emphasized,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final visibleChild = child.key == const ValueKey(true)
            ? animation
            : ReverseAnimation(animation);
        return FadeTransition(
          opacity: visibleChild,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.4),
              end: Offset.zero,
            ).animate(visibleChild),
            child: SizeTransition(sizeFactor: visibleChild, child: child),
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.bottomCenter,
        children: [...previousChildren, ?currentChild],
      ),
      child: visible
          ? KeyedSubtree(key: const ValueKey(true), child: child)
          : const SizedBox.shrink(key: ValueKey(false)),
    );
  }
}

class _MiniControlButton extends StatelessWidget {
  const _MiniControlButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      borderRadius: BorderRadius.circular(24),
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 26, color: palette.ink),
      ),
    );
  }
}

class _MiniProgressHairline extends ConsumerWidget {
  const _MiniProgressHairline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerServiceProvider);
    final palette = context.monora;
    final positionAsync = ref.watch(playerPositionProvider);
    final position = positionAsync.value ?? player.position;
    final duration = player.duration;
    final progress = duration == null || duration == Duration.zero
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress),
      duration: MonoraMotion.fast,
      builder: (context, value, _) {
        return LinearProgressIndicator(
          value: value,
          minHeight: 2,
          backgroundColor: palette.outline,
          valueColor: AlwaysStoppedAnimation(palette.accent),
        );
      },
    );
  }
}
