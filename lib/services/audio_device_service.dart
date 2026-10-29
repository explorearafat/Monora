import 'dart:async';

import 'package:flutter/services.dart';

import 'player_service.dart';

/// Listens to the native audio-device callback (see `MainActivity.kt`) and
/// resumes playback when a headphone/Bluetooth/car device connects right
/// after the music stopped because a device vanished.
abstract final class AudioDeviceService {
  static const EventChannel _channel = EventChannel('monora/audio_devices');

  /// Returns the subscription to cancel on dispose, or null when the platform
  /// side isn't available (desktop/web).
  static StreamSubscription<Object?>? watch(MonoraPlayerService service) {
    return _channel
        .receiveBroadcastStream()
        .listen((event) {
          if (event is Map && event['added'] == true) {
            unawaited(service.handleAudioDeviceConnected());
          }
        }, onError: (Object _) {
          // No device callback on this platform.
        });
  }
}
