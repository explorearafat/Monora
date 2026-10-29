import 'dart:async';

import 'package:flutter/services.dart';

/// Pushes "what's playing" state to the Android home screen widget. The widget
/// itself is native (`MonoraWidgetProvider.kt`); its transport buttons work
/// entirely through media-button broadcasts, so this one-way channel is the
/// only coupling needed. Failures are silently ignored — the widget just keeps
/// showing its last state (e.g. on platforms without the native side).
abstract final class HomeWidgetService {
  static const MethodChannel _channel = MethodChannel('monora/widget');

  static String? _lastTitle;
  static String? _lastArtist;
  static bool? _lastPlaying;

  static void push({
    required String? title,
    required String? artist,
    required bool playing,
  }) {
    if (title == _lastTitle &&
        artist == _lastArtist &&
        playing == _lastPlaying) {
      return;
    }
    _lastTitle = title;
    _lastArtist = artist;
    _lastPlaying = playing;
    unawaited(_invoke(title, artist, playing));
  }

  static Future<void> _invoke(String? title, String? artist, bool playing) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'title': title ?? 'Monora',
        'artist': artist ?? 'Nothing playing',
        'playing': playing,
      });
    } on PlatformException {
      // Native side unavailable — ignore.
    } on MissingPluginException {
      // Widget channel not registered — ignore.
    }
  }
}
