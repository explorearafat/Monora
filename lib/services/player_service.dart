// The constructor uses named private parameters because the fields are private;
// `this._x` initializing formals are not allowed for named parameters.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/library_models.dart';
import '../data/repositories/artwork_repository.dart';

/// Why the player reported a load failure, surfaced to the UI as a snackbar.
class PlaybackFailure {
  const PlaybackFailure({required this.track, required this.message});

  final Track track;
  final String message;
}

/// Owns the single [AudioPlayer] and everything playback-related: queue
/// management, shuffle/repeat, speed, sleep timer, and audio focus. The
/// Android media notification lives in [MonoraAudioHandler], which observes
/// the same player, so both sides always agree on the real playback state.
///
/// Widgets observe this through [ChangeNotifier] plus [positionStream]; all
/// mutation flows funnel through the command methods below so the UI can never
/// desynchronize the queue.
class MonoraPlayerService extends ChangeNotifier {
  MonoraPlayerService({
    required AudioPlayer player,
    required ArtworkRepository artworkRepository,
    AndroidEqualizer? equalizer,
    AndroidLoudnessEnhancer? loudnessEnhancer,
    Future<void> Function(Duration position, int index)? onPersistSession,
  }) : _player = player,
       _artworkRepository = artworkRepository,
       _equalizer = equalizer,
       _loudnessEnhancer = loudnessEnhancer,
       _onPersistSession = onPersistSession {
    _init();
  }

  final AudioPlayer _player;
  final ArtworkRepository _artworkRepository;
  final AndroidEqualizer? _equalizer;
  final AndroidLoudnessEnhancer? _loudnessEnhancer;
  final Future<void> Function(Duration position, int index)? _onPersistSession;

  /// Tracks for the loaded queue, keyed by original queue position.
  List<Track> _queue = const [];
  Timer? _sleepTimer;
  Duration _sleepRemaining = Duration.zero;
  int _consecutiveErrors = 0;
  bool _loadingQueue = false;
  Duration _lastPosition = Duration.zero;
  int _unaccountedListeningMs = 0;

  bool _pauseOnInterruptions = true;
  bool _skipSilence = false;
  bool _crossfadeEnabled = false;
  Duration _crossfadeDuration = const Duration(seconds: 4);
  bool _crossfading = false;
  Timer? _crossfadeTimer;
  bool _resumeOnReconnect = false;

  final StreamController<PlaybackFailure> _failureController =
      StreamController<PlaybackFailure>.broadcast();
  final ValueNotifier<Duration> sleepRemaining = ValueNotifier(Duration.zero);

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;
  Timer? _sessionPersistTimer;

  // --- Observable state ----------------------------------------------------

  bool get isPlaying => _player.playing;

  ProcessingState get processingState => _player.processingState;

  bool get isBuffering =>
      _player.processingState == ProcessingState.buffering ||
      _player.processingState == ProcessingState.loading;

  Duration get position => _player.position;

  Duration get bufferedPosition => _player.bufferedPosition;

  Duration? get duration => _player.duration;

  /// The queue in its logical (unshuffled) order.
  List<Track> get queue => List.unmodifiable(_queue);

  /// The effective play order, i.e. the order the Queue screen presents.
  List<Track> get playOrder {
    final effective = _player.effectiveIndices;
    if (effective.length != _queue.length) {
      return _queue;
    }
    return [for (final originalIndex in effective) _queue[originalIndex]];
  }

  Track? get currentTrack {
    final index = _player.currentIndex;
    if (index == null || index < 0 || index >= _queue.length) return null;
    return _queue[index];
  }

  /// Position of the current track within the effective play order.
  int? get currentPlayOrderIndex {
    final index = _player.currentIndex;
    if (index == null) return null;
    final effective = _player.effectiveIndices;
    final inverse = List.filled(effective.length, 0);
    for (var i = 0; i < effective.length; i++) {
      final original = effective[i];
      if (original >= 0 && original < inverse.length) {
        inverse[original] = i;
      }
    }
    if (index >= inverse.length) return null;
    return inverse[index];
  }

  bool get shuffleEnabled => _player.shuffleModeEnabled;

  LoopMode get repeatMode => _player.loopMode;

  double get speed => _player.speed;

  AndroidEqualizer? get equalizer => _equalizer;

  AndroidLoudnessEnhancer? get loudnessEnhancer => _loudnessEnhancer;

  bool get equalizerSupported => _equalizer != null;

  bool get sleepTimerActive => _sleepTimer != null;

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<PlaybackFailure> get failureStream => _failureController.stream;

  bool get hasNext => _player.hasNext || _player.loopMode != LoopMode.off;

  // --- Lifecycle -----------------------------------------------------------

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _interruptionSub = session.interruptionEventStream.listen(
        _onInterruption,
      );
      _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
        if (_player.playing) {
          _resumeOnReconnect = true;
          unawaited(_player.pause());
        }
      });
    } on Exception {
      // Audio focus is best-effort; playback works without it.
    }

    _stateSub = _player.playerStateStream.listen(_onPlayerState);
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) => _onPlayerError(error),
    );
    _positionSub = _player.positionStream.listen(_onPosition);
    _sessionPersistTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_persistSession()),
    );
    notifyListeners();
  }

  /// Reconfigures interruption handling after the user flips the setting.
  void setPauseOnInterruptions(bool value) {
    _pauseOnInterruptions = value;
  }

  /// Skips silent stretches inside files (just_audio platform support).
  Future<void> setSkipSilence(bool value) async {
    _skipSilence = value;
    try {
      await _player.setSkipSilenceEnabled(value);
    } on Exception {
      // Not supported on this platform/file — setting stays for next load.
    }
    notifyListeners();
  }

  bool get skipSilenceEnabled => _skipSilence;

  /// Configures the end-of-track fade that eases transitions between songs.
  void configureCrossfade({required bool enabled, required int seconds}) {
    _crossfadeEnabled = enabled;
    _crossfadeDuration = Duration(seconds: seconds.clamp(1, 12));
    if (!enabled) _cancelCrossfade();
  }

  /// A headphone/Bluetooth/car device came back: resume if the music only
  /// stopped because the previous one vanished (audio becoming noisy).
  Future<void> handleAudioDeviceConnected() async {
    if (!_resumeOnReconnect || _player.playing) return;
    _resumeOnReconnect = false;
    await playPause();
  }

  void _onInterruption(AudioInterruptionEvent event) {
    if (!_pauseOnInterruptions) return;
    if (event.begin) {
      if (event.type == AudioInterruptionType.duck) {
        unawaited(_player.setVolume(0.35));
      } else {
        _lastInterruptionWasPause = _player.playing;
        if (_player.playing) unawaited(_player.pause());
      }
    } else {
      if (event.type == AudioInterruptionType.duck) {
        unawaited(_player.setVolume(1.0));
      } else if (_lastInterruptionWasPause) {
        // Focus returned after a co-operative pause: pick up where we left.
        unawaited(_player.play());
      }
      _lastInterruptionWasPause = false;
    }
    notifyListeners();
  }

  bool _lastInterruptionWasPause = false;

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed &&
        _player.loopMode != LoopMode.one) {
      // End of the queue: restart paused at the top for a clean state.
      _cancelCrossfade();
      unawaited(_player.pause());
      unawaited(_player.seek(Duration.zero, index: 0));
    }
    notifyListeners();
  }

  void _onPosition(Duration position) {
    final deltaMs = position.inMilliseconds - _lastPosition.inMilliseconds;
    if (deltaMs > 0 && deltaMs < 2000) {
      _unaccountedListeningMs += deltaMs;
    }
    _lastPosition = position;
    _maybeCrossfade(position);
  }

  /// Fades the current track out over the last [_crossfadeDuration] and
  /// advances early, so consecutive songs transition without a hard cut.
  /// (Single-player approximation: the fade completes just as the file ends.)
  void _maybeCrossfade(Duration position) {
    if (!_crossfadeEnabled || _crossfading) return;
    if (!_player.playing || _player.processingState != ProcessingState.ready) {
      return;
    }
    if (_player.loopMode != LoopMode.off || !_player.hasNext) return;
    final duration = _player.duration;
    if (duration == null || duration <= _crossfadeDuration * 2) return;
    final remaining = duration - position;
    if (remaining <= Duration.zero || remaining > _crossfadeDuration) return;

    _crossfading = true;
    final startRemainingMs = remaining.inMilliseconds;
    _crossfadeTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      final left = duration - _player.position;
      final jumped = left.inMilliseconds > startRemainingMs + 500;
      if (jumped) {
        // The user skipped or the track changed underneath the fade.
        _cancelCrossfade();
        return;
      }
      final fraction = (left.inMilliseconds / startRemainingMs).clamp(0.0, 1.0);
      unawaited(_player.setVolume(0.02 + 0.98 * fraction));
      if (left <= const Duration(milliseconds: 250)) {
        _crossfading = false;
        timer.cancel();
        _crossfadeTimer = null;
        unawaited(() async {
          await _player.setVolume(1.0);
          await _player.seekToNext();
          if (!_player.playing) await _player.play();
        }());
      }
    });
  }

  void _cancelCrossfade() {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _crossfading = false;
    if (_player.volume != 1.0) {
      unawaited(_player.setVolume(1.0));
    }
  }

  void _onPlayerError(Object error) {
    if (error is! PlayerException) return;
    final track = currentTrack;
    _consecutiveErrors += 1;
    if (track != null) {
      _failureController.add(
        PlaybackFailure(
          track: track,
          message: 'Could not play "${track.title}" (code ${error.code}).',
        ),
      );
    }
    if (_consecutiveErrors <= _queue.length) {
      // Skip past the broken file instead of stalling the queue.
      unawaited(_safeSkipNext());
    }
  }

  Future<void> _safeSkipNext() async {
    try {
      if (_player.hasNext) {
        await _player.seekToNext();
        await _player.play();
      }
    } on Exception {
      // Nothing more we can do; leave playback paused.
    }
  }

  // --- Queue management ----------------------------------------------------

  /// Replaces the queue with [tracks], starting at [initialIndex], optionally
  /// at [initialPosition] (used by session restore).
  Future<void> loadQueue(
    List<Track> tracks, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
    bool autoplay = true,
  }) async {
    if (tracks.isEmpty) return;
    _queue = List.of(tracks);
    _consecutiveErrors = 0;
    _lastPosition = initialPosition;
    _cancelCrossfade();
    _loadingQueue = true;

    try {
      // Resolve notification artwork up front, bounded so huge libraries
      // don't hammer MediaStore. UI tiles resolve their own art separately.
      final artLimit = math.min(tracks.length, 30);
      final artUris = await Future.wait([
        for (var i = 0; i < artLimit; i++)
          _artworkRepository
              .artworkUri(tracks[i].id, ArtworkTarget.track)
              .timeout(
                const Duration(seconds: 3),
                onTimeout: () => Future.value(null),
              ),
      ]);

      final sources = <AudioSource>[
        for (var i = 0; i < tracks.length; i++)
          _buildSource(
            tracks[i],
            artUri: i < artUris.length ? artUris[i] : null,
          ),
      ];

      await _player.setAudioSources(
        sources,
        initialIndex: initialIndex.clamp(0, tracks.length - 1),
        initialPosition: initialPosition,
      );
      if (autoplay) {
        await _player.play();
      } else {
        await _player.pause();
      }
    } on Exception catch (error) {
      if (currentTrack != null) {
        _failureController.add(
          PlaybackFailure(
            track: currentTrack!,
            message: 'Could not start playback: $error',
          ),
        );
      }
    } finally {
      _loadingQueue = false;
      notifyListeners();
    }
  }

  AudioSource _buildSource(Track track, {Uri? artUri}) {
    return AudioSource.uri(
      track.uri,
      tag: MediaItem(
        id: '${track.id}',
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
        artUri: artUri,
      ),
    );
  }

  /// Starts playing [tracks] from the given track.
  Future<void> playTracks(List<Track> tracks, {Track? startFrom}) async {
    final index = startFrom == null ? 0 : tracks.indexOf(startFrom);
    await loadQueue(tracks, initialIndex: index < 0 ? 0 : index);
  }

  /// Jumps to the track at [playOrderIndex] in the effective play order.
  Future<void> playFromPlayOrder(int playOrderIndex) async {
    final effective = _player.effectiveIndices;
    if (playOrderIndex < 0 || playOrderIndex >= effective.length) return;
    _consecutiveErrors = 0;
    await _player.seek(Duration.zero, index: effective[playOrderIndex]);
    if (!_player.playing) await _player.play();
    notifyListeners();
  }

  /// Removes the item at [playOrderIndex] from the effective play order.
  Future<void> removeFromPlayOrder(int playOrderIndex) async {
    final effective = _player.effectiveIndices;
    if (playOrderIndex < 0 || playOrderIndex >= effective.length) return;
    final originalIndex = effective[playOrderIndex];
    await _player.removeAudioSourceAt(originalIndex);
    if (originalIndex < _queue.length) {
      _queue = List.of(_queue)..removeAt(originalIndex);
    }
    notifyListeners();
  }

  /// Drag-reorders within the effective play order. Only meaningful while
  /// shuffle is off; the queue screen hides handles otherwise.
  Future<void> moveInPlayOrder(int from, int to) async {
    if (shuffleEnabled) return;
    final effective = _player.effectiveIndices;
    if (from < 0 ||
        from >= effective.length ||
        to < 0 ||
        to >= effective.length) {
      return;
    }
    await _player.moveAudioSource(effective[from], effective[to]);
    final track = _queue.removeAt(effective[from]);
    _queue = List.of(_queue)..insert(effective[to], track);
    notifyListeners();
  }

  // --- Transport -----------------------------------------------------------

  Future<void> playPause() async {
    _cancelCrossfade();
    _resumeOnReconnect = false;
    try {
      if (_player.playing) {
        await _player.pause();
      } else if (_player.processingState == ProcessingState.idle &&
          _queue.isNotEmpty) {
        // After an explicit stop(): just_audio re-activates the released
        // platform player and resumes at the preserved position.
        await _player.play();
        return;
      } else {
        await _player.play();
      }
    } on Exception catch (error) {
      _onPlayerError(error);
    }
    notifyListeners();
  }

  Future<void> next() async {
    _consecutiveErrors = 0;
    _cancelCrossfade();
    try {
      if (_player.loopMode == LoopMode.one) {
        await _player.setLoopMode(LoopMode.off);
      }
      await _player.seekToNext();
      if (!_player.playing) await _player.play();
    } on Exception catch (error) {
      _onPlayerError(error);
    }
    notifyListeners();
  }

  Future<void> previous() async {
    _consecutiveErrors = 0;
    _cancelCrossfade();
    try {
      // Standard UX: a deep track restarts first, a second tap goes back.
      if (_player.position > const Duration(seconds: 3)) {
        await _player.seek(Duration.zero);
      } else {
        await _player.seekToPrevious();
      }
      if (!_player.playing) await _player.play();
    } on Exception catch (error) {
      _onPlayerError(error);
    }
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    _cancelCrossfade();
    _lastPosition = position;
    await _player.seek(position);
    notifyListeners();
  }

  /// Full stop requested by the user: halts decoding and releases the
  /// platform playback pipeline. The queue is kept so the mini-player can
  /// resume later via [playPause]; the media notification drops to its
  /// paused/idle state rather than continuing to advertise playback.
  Future<void> stop() async {
    _consecutiveErrors = 0;
    _cancelCrossfade();
    _resumeOnReconnect = false;
    try {
      await _player.stop();
    } on Exception {
      // A failed stop still leaves the player in a recoverable state.
    }
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    try {
      await _player.setShuffleModeEnabled(!_player.shuffleModeEnabled);
    } on Exception {
      // ignore: shuffle state simply stays as-is
    }
    notifyListeners();
  }

  Future<void> cycleRepeatMode() async {
    try {
      final nextMode = switch (_player.loopMode) {
        LoopMode.off => LoopMode.all,
        LoopMode.all => LoopMode.one,
        LoopMode.one => LoopMode.off,
      };
      await _player.setLoopMode(nextMode);
    } on Exception {
      // ignore: repeat state simply stays as-is
    }
    notifyListeners();
  }

  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed.clamp(0.5, 2.0));
    } on Exception {
      // ignore: speed simply stays as-is
    }
    notifyListeners();
  }

  // --- Sleep timer ----------------------------------------------------------

  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepRemaining = duration;
    sleepRemaining.value = duration;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _sleepRemaining -= const Duration(seconds: 1);
      if (_sleepRemaining <= Duration.zero) {
        timer.cancel();
        _sleepTimer = null;
        sleepRemaining.value = Duration.zero;
        unawaited(_player.pause());
        notifyListeners();
      } else {
        sleepRemaining.value = _sleepRemaining;
      }
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepRemaining = Duration.zero;
    sleepRemaining.value = Duration.zero;
    notifyListeners();
  }

  // --- Session persistence ---------------------------------------------------

  Future<void> _persistSession() async {
    if (_loadingQueue || _queue.isEmpty) return;
    final persist = _onPersistSession;
    if (persist == null) return;
    await persist(_lastPosition, _player.currentIndex ?? 0);
  }

  /// Milliseconds of listening time accrued since the last flush (used by the
  /// profile screen's listening-time stat).
  int drainListeningMillis() {
    final value = _unaccountedListeningMs;
    _unaccountedListeningMs = 0;
    return value;
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _crossfadeTimer?.cancel();
    _stateSub?.cancel();
    _positionSub?.cancel();
    _interruptionSub?.cancel();
    _becomingNoisySub?.cancel();
    _sessionPersistTimer?.cancel();
    _failureController.close();
    sleepRemaining.dispose();
    _player.dispose();
    super.dispose();
  }
}
