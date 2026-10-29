import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../providers/player_providers.dart';

/// Tiny three-bar equalizer that animates only while audio is actually
/// playing: it starts on play, freezes on pause/buffer/interruption, and
/// stays frozen until playback resumes. Always sourced from the real player
/// state, never from a local "should look busy" flag.
class PlayingBars extends ConsumerStatefulWidget {
  const PlayingBars({super.key, this.color});

  /// Defaults to the theme accent.
  final Color? color;

  @override
  ConsumerState<PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends ConsumerState<PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _syncWithPlayback();
  }

  void _syncWithPlayback() {
    final playing = ref.read(playerServiceProvider).isPlaying;
    if (playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(PlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWithPlayback();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever the real playing flag flips so the bars freeze/resume.
    ref.listen(
      playerServiceProvider.select((player) => player.isPlaying),
      (_, _) => _syncWithPlayback(),
    );
    final color = widget.color ?? context.monora.accent;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 18,
          height: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 3,
                  height: 5 + 8 * (0.5 + 0.5 * _barOffset(i)),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _barOffset(int i) =>
      (0.5 +
      0.5 *
          (Curves.easeInOut.transform((_controller.value * 2 + i * 0.33) % 1)));
}
