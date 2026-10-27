import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/library_models.dart';
import '../data/repositories/preferences_repository.dart';
import '../services/player_service.dart';
import 'app_providers.dart';

/// The single app-lifetime player service.
///
/// The Android audio-effect pipeline (equalizer + loudness enhancer) must be
/// attached when the [AudioPlayer] is constructed, so it is created here and
/// handed to the service.
final playerServiceProvider = Provider<MonoraPlayerService>((ref) {
  final isAndroid = !kIsWeb && Platform.isAndroid;
  final equalizer = isAndroid ? AndroidEqualizer() : null;
  final loudnessEnhancer = isAndroid ? AndroidLoudnessEnhancer() : null;

  final player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [?equalizer, ?loudnessEnhancer],
    ),
  );

  final repository = ref.watch(preferencesRepositoryProvider);

  late final MonoraPlayerService service;
  service = MonoraPlayerService(
    player: player,
    artworkRepository: ref.watch(artworkRepositoryProvider),
    equalizer: equalizer,
    loudnessEnhancer: loudnessEnhancer,
    onPersistSession: (position, index) async {
      final ids = service.queue.map((track) => track.id).take(300).toList();
      await repository.saveLastSession(
        LastSessionSnapshot(
          trackIds: ids,
          trackIndex: index,
          positionMs: position.inMilliseconds,
          shuffle: service.shuffleEnabled,
          loopModeIndex: service.repeatMode.index,
        ),
      );
    },
  );

  // Flush listening time periodically.
  final statsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    final millis = service.drainListeningMillis();
    if (millis > 0) {
      unawaited(ref.read(listeningSecondsProvider.notifier).addMillis(millis));
    }
  });
  ref.onDispose(() {
    statsTimer.cancel();
    service.dispose();
  });
  return service;
});

/// Throttled playback position for seek bars and the mini-player progress
/// hairline.
final playerPositionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(playerServiceProvider).positionStream;
});

/// Restores the last session (queue snapshot) when the user has the feature
/// enabled. Called once from the splash flow after the library is ready.
Future<void> restoreSessionIfNeeded(WidgetRef ref) async {
  final repository = ref.read(preferencesRepositoryProvider);
  final resumeEnabled = repository.loadResumeSession();
  if (!resumeEnabled) return;

  final snapshot = repository.loadLastSession();
  if (snapshot == null || snapshot.trackIds.isEmpty) return;

  final tracksById = ref.read(tracksByIdProvider);
  final tracks = <Track>[
    for (final id in snapshot.trackIds)
      if (tracksById.containsKey(id)) tracksById[id]!,
  ];
  if (tracks.isEmpty) return;

  final service = ref.read(playerServiceProvider);
  final index = snapshot.trackIndex.clamp(0, tracks.length - 1);
  await service.loadQueue(
    tracks,
    initialIndex: index,
    initialPosition: Duration(milliseconds: snapshot.positionMs),
    autoplay: false,
  );
  await service.setSpeed(repository.loadPlaybackSpeed());
  if (snapshot.shuffle) {
    await service.toggleShuffle();
  }
  if (snapshot.loopModeIndex >= 0 && snapshot.loopModeIndex <= 2) {
    await service.cycleRepeatModeTo(snapshot.loopModeIndex);
  }
}

/// Ensures the persisted playback speed is applied whenever the setting
/// changes or the player (re)loads a queue.
void applyPlaybackSpeed(WidgetRef ref) {
  final speed = ref.read(playbackSpeedProvider);
  unawaited(ref.read(playerServiceProvider).setSpeed(speed));
}

/// Used above to convert a persisted loop-mode index without cycling through
/// intermediate modes.
extension LoopModeRestore on MonoraPlayerService {
  Future<void> cycleRepeatModeTo(int modeIndex) async {
    final target =
        LoopMode.values[modeIndex.clamp(0, LoopMode.values.length - 1)];
    while (repeatMode != target) {
      await cycleRepeatMode();
    }
  }
}
