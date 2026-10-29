import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/library_models.dart';
import '../data/repositories/preferences_repository.dart';
import '../services/audio_device_service.dart';
import '../services/audio_handler.dart';
import '../services/player_service.dart';
import 'app_providers.dart';

/// The single app-lifetime [AudioPlayer], built in `main()` (its effect
/// pipeline must exist at construction time) and overridden at bootstrap.
final audioPlayerProvider = Provider<AudioPlayer>(
  (ref) => throw UnimplementedError(
    'audioPlayerProvider must be overridden at bootstrap',
  ),
);

/// Optional Android equalizer, built in `main()` on Android only.
final audioEqualizerProvider = Provider<AndroidEqualizer?>((ref) => null);

/// Optional Android loudness enhancer, built in `main()` on Android only.
final audioLoudnessEnhancerProvider = Provider<AndroidLoudnessEnhancer?>(
  (ref) => null,
);

/// The MediaSession handler registered with audio_service, or null on
/// platforms without media-notification support (e.g. Windows desktop).
final audioHandlerProvider = Provider<MonoraAudioHandler?>((ref) => null);

/// The single app-lifetime player service.
///
/// All notification/lock-screen concerns live in [MonoraAudioHandler], which
/// observes the same [AudioPlayer] — this service only owns queue management
/// and app-facing state, so UI and MediaSession can never diverge.
final playerServiceProvider = Provider<MonoraPlayerService>((ref) {
  final repository = ref.watch(preferencesRepositoryProvider);
  // `late` so the persist callback can reference the service it belongs to.
  late final MonoraPlayerService service;
  service = MonoraPlayerService(
    player: ref.watch(audioPlayerProvider),
    artworkRepository: ref.watch(artworkRepositoryProvider),
    equalizer: ref.watch(audioEqualizerProvider),
    loudnessEnhancer: ref.watch(audioLoudnessEnhancerProvider),
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

  // Apply persisted playback extras.
  unawaited(service.setSkipSilence(repository.loadSkipSilence()));
  service.configureCrossfade(
    enabled: repository.loadCrossfade(),
    seconds: repository.loadCrossfadeSeconds(),
  );

  // Resume when headphones/Bluetooth/car devices come back.
  final deviceSub = AudioDeviceService.watch(service);

  // Flush listening time periodically.
  final statsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    final millis = service.drainListeningMillis();
    if (millis > 0) {
      unawaited(ref.read(listeningSecondsProvider.notifier).addMillis(millis));
    }
  });
  ref.onDispose(() {
    statsTimer.cancel();
    deviceSub?.cancel();
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
