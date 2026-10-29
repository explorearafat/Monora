import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme/app_colors.dart';
import '../../data/models/library_models.dart';
import '../../providers/app_providers.dart';

/// Shares the card through the native Android share sheet (see
/// MainActivity.kt `shareImage`), avoiding an extra share plugin.
const MethodChannel _systemChannel = MethodChannel('monora/system');

/// A shareable "Monora Wrapped" card: listening time, top artist, top song,
/// and top genre rendered as a poster the user can share anywhere.
class WrappedScreen extends ConsumerStatefulWidget {
  const WrappedScreen({super.key});

  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends ConsumerState<WrappedScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) return;
      if (!mounted) return;

      final tempDir = await getTemporaryDirectory();
      final sharedDir = Directory('${tempDir.path}/shared');
      await sharedDir.create(recursive: true);
      final file = File('${sharedDir.path}/monora_wrapped.png');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;

      await _systemChannel.invokeMethod<void>('shareImage', {
        'path': file.path,
        'text': 'My Monora Wrapped 🎧',
      });
    } on PlatformException catch (error) {
      if (mounted && error.code == 'UNAVAILABLE') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sharing works on the Android app.'),
          ),
        );
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sharing works on the Android app.'),
          ),
        );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the card to share.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(profileStatsProvider);
    final name = ref.watch(profileNameProvider);
    final playCounts = ref.watch(playCountsProvider);
    final library = ref.watch(libraryProvider).value;

    Track? topTrack;
    var topCount = 0;
    String? topArtist;
    var artistPlays = <String, int>{};
    for (final track in library?.tracks ?? const []) {
      final count = playCounts[track.id] ?? 0;
      if (count > topCount) {
        topCount = count;
        topTrack = track;
      }
      if (count > 0) {
        artistPlays[track.artist] = (artistPlays[track.artist] ?? 0) + count;
      }
    }
    var bestArtistPlays = 0;
    for (final entry in artistPlays.entries) {
      if (entry.value > bestArtistPlays) {
        bestArtistPlays = entry.value;
        topArtist = entry.key;
      }
    }
    final topGenre = stats.topGenres.isEmpty ? null : stats.topGenres.first;
    final hours = stats.listeningTime.inHours;
    final minutes = stats.listeningTime.inMinutes % 60;

    final content = Scaffold(
      backgroundColor: MonoraColors.logoInk,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 30,
            color: MonoraColors.logoBar,
          ),
          tooltip: 'Back',
        ),
        title: const Text(
          'Wrapped',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            color: MonoraColors.logoBar,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _sharing ? null : _share,
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        MonoraColors.logoBar,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.ios_share_rounded,
                    size: 21,
                    color: MonoraColors.logoBar,
                  ),
            tooltip: 'Share card',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: RepaintBoundary(
            key: _cardKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    MonoraColors.accent,
                    MonoraColors.accentDeep,
                    Color(0xFF3A160A),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MONORA WRAPPED',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 2.4,
                      color: MonoraColors.logoBar.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Playfair',
                      fontWeight: FontWeight.w700,
                      fontSize: 32,
                      height: 1.1,
                      color: MonoraColors.logoBar,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _WrappedStat(
                    label: 'Time with music',
                    value: hours > 0
                        ? '$hours hr $minutes min'
                        : '${stats.listeningTime.inMinutes} min',
                  ),
                  _WrappedStat(
                    label: 'Songs in your library',
                    value: '${stats.totalSongs}',
                  ),
                  _WrappedStat(
                    label: 'Top artist',
                    value: topArtist ?? '—',
                  ),
                  _WrappedStat(
                    label: 'Top song',
                    value: topTrack == null
                        ? '—'
                        : '${topTrack.title}${topCount > 0 ? ' ($topCount plays)' : ''}',
                  ),
                  _WrappedStat(
                    label: 'Top genre',
                    value: topGenre?.name ?? '—',
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Your sound. Your space.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: MonoraColors.logoBar,
                          ),
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: MonoraColors.logoInk,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.music_note_rounded,
                          size: 16,
                          color: MonoraColors.logoBar,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: MonoraColors.logoInk,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: content,
    );
  }
}

class _WrappedStat extends StatelessWidget {
  const _WrappedStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 10,
              letterSpacing: 1.6,
              color: MonoraColors.logoBar.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Playfair',
              fontWeight: FontWeight.w600,
              fontSize: 21,
              color: MonoraColors.logoBar,
            ),
          ),
        ],
      ),
    );
  }
}
