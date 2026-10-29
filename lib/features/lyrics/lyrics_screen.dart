import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/lrc_parser.dart';
import '../../core/widgets/common.dart';
import '../../data/models/library_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/player_providers.dart';

/// Synced lyrics view. Lyric content comes exclusively from offline `.lrc`
/// files — Monora never fabricates lyrics when none exist.
class LyricsScreen extends ConsumerStatefulWidget {
  const LyricsScreen({super.key, required this.track});

  final Track track;

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;
  late final Future<LrcContent?> _lyricsFuture;
  bool _fullLyricsMode = false;
  final ScrollController _scrollController = ScrollController();
  int? _lastAutoIndex;
  _LyricsBackdrop? _backdrop;

  static const double _lineExtent = 76;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _lyricsFuture = ref.read(lyricsRepositoryProvider).findLyrics(widget.track);
    _resolveBackdrop();
    ref.read(playerServiceProvider).addListener(_syncWave);
    _syncWave();
  }

  Future<void> _resolveBackdrop() async {
    String? path;
    try {
      path = await ref
          .read(artworkRepositoryProvider)
          .artworkPath(widget.track.id, ArtworkTarget.track);
    } on Exception {
      return;
    }
    if (!mounted || path == null) return;
    List<int>? bytes;
    try {
      bytes = await File(path).readAsBytes();
    } on Exception {
      return;
    }
    if (!mounted) return;
    final backdrop = await _computeBackdrop(bytes);
    if (!mounted) return;
    setState(() => _backdrop = backdrop);
  }

  void _syncWave() {
    final playing = ref.read(playerServiceProvider).isPlaying;
    if (playing && !_wave.isAnimating) {
      _wave.repeat();
    } else if (!playing && _wave.isAnimating) {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    ref.read(playerServiceProvider).removeListener(_syncWave);
    _wave.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backdrop = _backdrop ?? _LyricsBackdrop.fallback();
    final positionAsync = ref.watch(playerPositionProvider);
    final position = positionAsync.value ?? Duration.zero;
    final duration = ref.watch(
      playerServiceProvider.select((player) => player.duration),
    );

    return Scaffold(
      backgroundColor: backdrop.base,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(gradient: backdrop.gradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LyricsTopBar(
                fullLyricsMode: _fullLyricsMode,
                onModeChanged: (full) => setState(() => _fullLyricsMode = full),
              ),
              Expanded(
                child: FutureBuilder<LrcContent?>(
                  future: _lyricsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(
                              Color(0xFFF6EFE2),
                            ),
                          ),
                        ),
                      );
                    }
                    final content = snapshot.data;
                    if (content == null || !content.hasText) {
                      return const _NoLyricsState();
                    }

                    final activeIndex = _fullLyricsMode
                        ? -2
                        : LrcParser.activeIndexFor(content.lines, position);
                    _maybeAutoScroll(content.lines.length, activeIndex);

                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        vertical: MediaQuery.sizeOf(context).height * 0.14,
                        horizontal: 28,
                      ),
                      itemExtent: _lineExtent,
                      itemCount: content.lines.length,
                      itemBuilder: (context, index) {
                        final line = content.lines[index];
                        final isActive = index == activeIndex;
                        return GestureDetector(
                          // Karaoke-style tap-to-seek: any line jumps playback
                          // to its timestamp.
                          onTap: () => unawaited(
                            ref.read(playerServiceProvider).seek(line.time),
                          ),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 260),
                            opacity: isActive
                                ? 1.0
                                : (activeIndex == -2 ? 0.88 : 0.5),
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 260),
                              style:
                                  (isActive
                                          ? MonoraText.lyricsActive(
                                              const Color(0xFFFFFFFF),
                                            )
                                          : MonoraText.lyricsIdle(
                                              const Color(0xFFF6EFE2),
                                            ))
                                      .copyWith(
                                        fontSize: _fullLyricsMode ? 21 : 28,
                                      ),
                              child: Text(
                                line.text.isEmpty ? '···' : line.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              _LyricsFooter(
                position: position,
                duration: duration,
                wave: _wave,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _maybeAutoScroll(int lineCount, int activeIndex) {
    if (_fullLyricsMode) return;
    if (!_scrollController.hasClients) return;
    if (activeIndex < 0 || activeIndex == _lastAutoIndex) return;
    _lastAutoIndex = activeIndex;
    final target =
        (activeIndex * _lineExtent - MediaQuery.sizeOf(context).height * 0.26)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }
}

/// Colors extracted from the track's artwork so the lyrics backdrop feels
/// native to the album (falls back to the Monora accent family).
class _LyricsBackdrop {
  const _LyricsBackdrop({required this.base, required this.gradient});

  final Color base;
  final Gradient gradient;

  static _LyricsBackdrop fallback() => const _LyricsBackdrop(
    base: MonoraColors.accentDeep,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [MonoraColors.accent, MonoraColors.accentDeep, Color(0xFF6E2A15)],
    ),
  );
}

/// Averages the album art pixels (skipping the extremes) and deepens the
/// result so white lyrics always stay readable. Kept dependency-free.
Future<_LyricsBackdrop?> _computeBackdrop(List<int>? artworkBytes) async {
  if (artworkBytes == null || artworkBytes.length < 24) return null;
  try {
    final codec = await ui.instantiateImageCodec(
      Uint8List.fromList(artworkBytes),
      targetWidth: 24,
      targetHeight: 24,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) return null;

    var r = 0;
    var g = 0;
    var b = 0;
    var count = 0;
    final pixels = byteData.buffer.asUint8List();
    for (var i = 0; i + 2 < pixels.length; i += 4) {
      final pr = pixels[i];
      final pg = pixels[i + 1];
      final pb = pixels[i + 2];
      final luminance = 0.299 * pr + 0.587 * pg + 0.114 * pb;
      if (luminance < 30 || luminance > 235) continue;
      r += pr;
      g += pg;
      b += pb;
      count++;
    }
    if (count == 0) return null;
    var base = Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count);
    final hsl = HSLColor.fromColor(base);
    base = hsl
        .withSaturation((hsl.saturation * 1.25).clamp(0.35, 0.85))
        .withLightness((hsl.lightness * 0.62).clamp(0.16, 0.42))
        .toColor();
    return _LyricsBackdrop(
      base: base,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(base, Colors.white, 0.10)!,
          base,
          Color.lerp(base, Colors.black, 0.42)!,
        ],
      ),
    );
  } on Exception {
    return null;
  }
}

class _LyricsTopBar extends StatelessWidget {
  const _LyricsTopBar({
    required this.fullLyricsMode,
    required this.onModeChanged,
  });

  final bool fullLyricsMode;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.chevron_left_rounded,
              size: 30,
              color: Color(0xFFF6EFE2),
            ),
            tooltip: 'Back',
          ),
          const Expanded(
            child: Text(
              'Lyrics',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
                letterSpacing: 0.2,
                color: Color(0xFFF6EFE2),
              ),
            ),
          ),
          _ModePills(
            fullLyricsMode: fullLyricsMode,
            onModeChanged: onModeChanged,
          ),
        ],
      ),
    );
  }
}

class _ModePills extends StatelessWidget {
  const _ModePills({required this.fullLyricsMode, required this.onModeChanged});

  final bool fullLyricsMode;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill('Line by Line', !fullLyricsMode, () => onModeChanged(false)),
          _pill('Full Lyrics', fullLyricsMode, () => onModeChanged(true)),
        ],
      ),
    );
  }

  Widget _pill(String label, bool active, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF6EFE2) : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: active ? const Color(0xFF2A1B12) : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _NoLyricsState extends StatelessWidget {
  const _NoLyricsState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lyrics_outlined, size: 44, color: Colors.white70),
          SizedBox(height: 16),
          Text(
            'No lyrics for this track',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Playfair',
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: Color(0xFFF6EFE2),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Monora reads offline .lrc files only. Place “<song name>.lrc” next to the audio file — or in the app’s lyrics folder — and reopen this screen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 13,
              height: 1.5,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricsFooter extends ConsumerWidget {
  const _LyricsFooter({
    required this.position,
    required this.duration,
    required this.wave,
  });

  final Duration position;
  final Duration? duration;
  final AnimationController wave;

  static const _timeStyle = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
    fontSize: 11.5,
    letterSpacing: 0.4,
    color: Colors.white70,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = duration ?? Duration.zero;
    final progress = total == Duration.zero
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Column(
        children: [
          Row(
            children: [
              Text(formatDuration(position), style: _timeStyle),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: const Duration(milliseconds: 180),
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 2.4,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFF6EFE2),
                        ),
                        borderRadius: BorderRadius.circular(2),
                      );
                    },
                  ),
                ),
              ),
              Text(formatDuration(total), style: _timeStyle),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 26,
            child: AnimatedBuilder(
              animation: wave,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 28; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          width: 3,
                          height: 5 + 18 * _barHeight(i, wave.value),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Deterministic, music-ish bar heights from layered sines; the phase only
  /// advances while the wave controller animates (i.e. while playing).
  double _barHeight(int index, double phase) {
    const barCount = 28.0;
    final x = index / barCount;
    final waveA = 0.5 + 0.5 * math.sin((x * 9 + phase * 6.28) * math.pi);
    final waveB = 0.5 + 0.5 * math.sin((x * 23 - phase * 12.56) * math.pi);
    final emphasis = 0.55 + 0.45 * math.sin(x * math.pi);
    return ((waveA * 0.6 + waveB * 0.4) * emphasis).clamp(0.0, 1.0);
  }
}
