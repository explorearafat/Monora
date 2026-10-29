import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/library_models.dart';

import 'package:just_audio/just_audio.dart' show LoopMode;

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/artwork.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/track_tile.dart';
import '../../providers/player_providers.dart';
import '../../services/player_service.dart';
import '../lyrics/lyrics_screen.dart';
import '../settings/settings_sheets.dart';
import 'player_actions.dart';
import 'queue_sheet.dart';

/// Full-screen immersive player. Colors are fixed (near-black + cream)
/// regardless of the app theme, exactly like the reference design.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key, this.heroTag});

  final String? heroTag;

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
      lowerBound: 0,
      upperBound: 1,
    );
    final player = ref.read(playerServiceProvider);
    _breathe.value = player.isPlaying ? 1 : 0;
    player.addListener(_syncBreathe);
  }

  void _syncBreathe() {
    final playing = ref.read(playerServiceProvider).isPlaying;
    if (playing && !_breathe.isAnimating) {
      _breathe.repeat(reverse: true);
    } else if (!playing && _breathe.isAnimating) {
      _breathe.stop();
    }
  }

  @override
  void dispose() {
    ref.read(playerServiceProvider).removeListener(_syncBreathe);
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerServiceProvider);
    final track = player.currentTrack;

    // Immersive chrome behind the translucent route.
    final overlayStyle = SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: MonoraColors.playerBg,
      systemNavigationBarIconBrightness: Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: MonoraColors.playerBg,
        body: SafeArea(
          bottom: false,
          child: track == null
              ? Center(
                  child: Text(
                    'Nothing is playing',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: const Color(0xFFA99F8D),
                    ),
                  ),
                )
              : Column(
                  children: [
                    _TopBar(track: track),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight:
                                MediaQuery.sizeOf(context).height -
                                MediaQuery.paddingOf(context).top -
                                180,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ArtworkPanel(
                                track: track,
                                heroTag: widget.heroTag,
                                breathe: _breathe,
                              ),
                              _TrackInfo(track: track),
                              _ProgressSection(player: player),
                              _TransportControls(player: player),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _BottomActions(track: track, player: player),
                    const SizedBox(height: 10),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.chevron_left_rounded,
              size: 30,
              color: Color(0xFFF1EBDF),
            ),
            tooltip: 'Back',
          ),
          const Expanded(
            child: Text(
              'Now Playing',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
                letterSpacing: 0.2,
                color: Color(0xFFF1EBDF),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showPlayerMenu(context, ref, track),
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 24,
              color: Color(0xFFF1EBDF),
            ),
            tooltip: 'More options',
          ),
        ],
      ),
    );
  }
}

Future<void> _showPlayerMenu(BuildContext context, WidgetRef ref, Track track) {
  return showOptionSheet(
    context,
    title: track.title,
    subtitle: track.artist,
    options: [
      OptionSheetItem(
        icon: Icons.speed_rounded,
        label: 'Playback speed…',
        onSelected: () => showSpeedSheet(context, ref),
      ),
      OptionSheetItem(
        icon: Icons.nightlight_round,
        label: 'Sleep timer…',
        onSelected: () => showSleepTimerSheet(context, ref),
      ),
      OptionSheetItem(
        icon: Icons.playlist_add_rounded,
        label: 'Add to playlist…',
        onSelected: () => showTrackOptions(context, ref, track),
      ),
      OptionSheetItem(
        icon: Icons.stop_circle_outlined,
        label: 'Stop playback',
        destructive: true,
        onSelected: () =>
            unawaited(ref.read(playerServiceProvider).stop()),
      ),
    ],
  );
}

class _ArtworkPanel extends StatelessWidget {
  const _ArtworkPanel({
    required this.track,
    required this.heroTag,
    required this.breathe,
  });

  final Track track;
  final String? heroTag;
  final AnimationController breathe;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final artSize = (size.width * 0.72).clamp(240.0, 340.0);

    Widget art = ArtworkTile(
      entityId: track.id,
      target: ArtworkTarget.track,
      size: artSize,
      radius: 26,
      heroTag: heroTag,
    );

    return AnimatedBuilder(
      animation: breathe,
      builder: (context, child) {
        final t = breathe.value;
        return Transform.scale(scale: 1.0 + 0.014 * t, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: RadialGradient(
            colors: [
              MonoraColors.accent.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ),
        ),
        child: art,
      ),
    );
  }
}

class _TrackInfo extends ConsumerWidget {
  const _TrackInfo({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: MonoraText.playerTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  '${track.artist}  ·  ${track.album}',
                  style: MonoraText.playerSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          FavoriteToggle(trackId: track.id, idleColor: const Color(0xFFA99F8D)),
        ],
      ),
    );
  }
}

class _ProgressSection extends ConsumerStatefulWidget {
  const _ProgressSection({required this.player});

  final MonoraPlayerService player;

  @override
  ConsumerState<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends ConsumerState<_ProgressSection> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(playerPositionProvider);
    final position = _dragValue == null
        ? (positionAsync.value ?? widget.player.position)
        : Duration(milliseconds: _dragValue!.round());
    final duration = widget.player.duration ?? Duration.zero;

    final progress = duration == Duration.zero
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFEFE7D7),
              inactiveTrackColor: const Color(0xFF3A3226),
              thumbColor: const Color(0xFFEFE7D7),
              trackHeight: 3,
            ),
            child: Slider(
              value: progress,
              onChanged: duration == Duration.zero
                  ? null
                  : (value) => setState(
                      () => _dragValue = value * duration.inMilliseconds,
                    ),
              onChangeEnd: (value) {
                unawaited(
                  widget.player.seek(
                    Duration(
                      milliseconds: (value * duration.inMilliseconds).round(),
                    ),
                  ),
                );
                setState(() => _dragValue = null);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDuration(position), style: MonoraText.playerTime),
              Text(formatDuration(duration), style: MonoraText.playerTime),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.player});

  final MonoraPlayerService player;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 6, 28, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SideControl(
            icon: player.shuffleEnabled
                ? Icons.shuffle_on_rounded
                : Icons.shuffle_rounded,
            active: player.shuffleEnabled,
            semanticLabel: player.shuffleEnabled ? 'Shuffle on' : 'Shuffle off',
            onTap: () => unawaited(player.toggleShuffle()),
          ),
          _SkipButton(
            icon: Icons.skip_previous_rounded,
            semanticLabel: 'Previous track',
            onTap: () => unawaited(player.previous()),
          ),
          _PlayPauseButton(player: player),
          _SkipButton(
            icon: Icons.skip_next_rounded,
            semanticLabel: 'Next track',
            onTap: () => unawaited(player.next()),
          ),
          _SideControl(
            icon: switch (player.repeatMode) {
              LoopMode.off => Icons.repeat_rounded,
              LoopMode.all => Icons.repeat_on_rounded,
              LoopMode.one => Icons.repeat_one_on_rounded,
            },
            active: player.repeatMode != LoopMode.off,
            semanticLabel: switch (player.repeatMode) {
              LoopMode.off => 'Repeat off',
              LoopMode.all => 'Repeat all',
              LoopMode.one => 'Repeat one',
            },
            onTap: () => unawaited(player.cycleRepeatMode()),
          ),
        ],
      ),
    );
  }
}

class _SideControl extends StatelessWidget {
  const _SideControl({
    required this.icon,
    required this.active,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.88,
      borderRadius: BorderRadius.circular(24),
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: 46,
        height: 46,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            icon,
            key: ValueKey(icon),
            size: 24,
            color: active ? MonoraColors.accent : const Color(0xFFA99F8D),
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      borderRadius: BorderRadius.circular(30),
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Icon(icon, size: 34, color: const Color(0xFFF1EBDF)),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.player});

  final MonoraPlayerService player;

  @override
  Widget build(BuildContext context) {
    final playing = player.isPlaying;
    final buffering = player.isBuffering;
    return Pressable(
      onTap: buffering ? null : () => unawaited(player.playPause()),
      scale: 0.93,
      borderRadius: BorderRadius.circular(38),
      semanticLabel: playing ? 'Pause' : 'Play',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: const Color(0xFFF1EBDF),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: buffering
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF211D17)),
                ),
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(playing),
                  size: 38,
                  color: const Color(0xFF211D17),
                ),
              ),
      ),
    );
  }
}

class _BottomActions extends ConsumerWidget {
  const _BottomActions({required this.track, required this.player});

  final Track track;
  final MonoraPlayerService player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              onTap: () => pushDetail(context, LyricsScreen(track: track)),
              borderRadius: BorderRadius.circular(26),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: MonoraColors.playerSurface,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lyrics_outlined,
                      size: 20,
                      color: const Color(0xFFA99F8D),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Lyrics',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: const Color(0xFFEFE7D7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Pressable(
            onTap: () => showQueueSheet(context),
            borderRadius: BorderRadius.circular(26),
            semanticLabel: 'Open queue',
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: MonoraColors.playerSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.format_list_bulleted_rounded,
                size: 21,
                color: const Color(0xFFEFE7D7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
