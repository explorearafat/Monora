import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'widget_service.dart';

/// The glue between Monora's single [AudioPlayer] and Android's MediaSession:
/// the media notification, lock-screen controls, artwork, and playback state
/// broadcast.
///
/// The handler runs inside a foreground service that outlives the UI. When
/// the user swipes the app away from recents (or closes it fully),
/// [onTaskRemoved] deliberately does nothing so playback continues — exactly
/// like the big players. Music stops only through the notification's Stop
/// control, the in-app "Stop playback" action, or the queue finishing.
class MonoraAudioHandler extends BaseAudioHandler with SeekHandler {
  MonoraAudioHandler(this._player) {
    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object _, StackTrace _) {
        // State stays at its last known value on stream errors; the service
        // surfaces the failure to the UI separately.
      },
    );
    _player.playerStateStream.listen(
      (_) => _broadcastState(_player.playbackEvent),
    );
    _player.sequenceStateStream.listen((state) {
      final item = state.currentSource?.tag;
      if (item is MediaItem) {
        mediaItem.add(item);
        HomeWidgetService.push(
          title: item.title,
          artist: item.artist,
          playing: _player.playing,
        );
      }
    });
    _player.sequenceStream.listen((sources) {
      queue.add([
        for (final source in sources)
          if (source.tag is MediaItem) source.tag as MediaItem,
      ]);
    });
  }

  final AudioPlayer _player;

  @override
  Future<void> play() async {
    // JustAudio restores the released platform player after a stop() on its
    // own; a plain play() resumes the preserved queue.
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position, {int? index}) =>
      _player.seek(position, index: index);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  /// The notification's explicit Stop control: halts decoding, releases the
  /// playback pipeline, and leaves a paused-state notification.
  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
    // Idle events are normally skipped in _broadcastState so a fresh launch
    // never posts a stray notification; after an explicit stop we do want one
    // final broadcast so the notification stops advertising "playing".
    playbackState.add(
      (playbackState.valueOrNull ??
              PlaybackState(
                processingState: AudioProcessingState.idle,
                playing: false,
              ))
          .copyWith(
        controls: const [MediaControl.play, MediaControl.stop],
        androidCompactActionIndices: const [0],
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: _player.position,
      ),
    );
  }

  /// Swiping the app out of recents must NOT end the session. Keeping the
  /// default no-op is the whole point of this override; document it so it is
  /// never "fixed" into a stop by accident.
  @override
  Future<void> onTaskRemoved() async {}

  /// The ongoing notification is only dismissible once playback has stopped,
  /// so a deletion while music plays should not stop it either.
  @override
  Future<void> onNotificationDeleted() async {}

  /// Mirrors the player's event into the MediaSession. Idle is skipped (the
  /// just_audio_background convention) so a freshly launched app never posts
  /// a stray notification before anything has played.
  void _broadcastState(PlaybackEvent event) {
    if (event.processingState == ProcessingState.idle) return;
    final playing = _player.playing;
    final controls = <MediaControl>[
      MediaControl.skipToPrevious,
      playing ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.stop,
    ];
    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        // Compact row: prev, play/pause, next. Stop lives in the expanded
        // notification where it can't be mis-touched.
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[event.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
    final item = mediaItem.valueOrNull;
    HomeWidgetService.push(
      title: item?.title,
      artist: item?.artist,
      playing: playing,
    );
  }
}
