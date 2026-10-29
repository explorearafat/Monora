import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'providers/app_providers.dart';
import 'providers/player_providers.dart';
import 'services/audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supportsMediaNotifications =
      !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  // The Android audio-effect pipeline (equalizer + loudness enhancer) must be
  // attached when the AudioPlayer is constructed, so the player and the media
  // notification handler are built here and handed to the providers.
  final AndroidEqualizer? equalizer = Platform.isAndroid
      ? AndroidEqualizer()
      : null;
  final AndroidLoudnessEnhancer? loudnessEnhancer = Platform.isAndroid
      ? AndroidLoudnessEnhancer()
      : null;
  final player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [?equalizer, ?loudnessEnhancer],
    ),
  );
  MonoraAudioHandler? audioHandler;
  if (supportsMediaNotifications) {
    audioHandler = MonoraAudioHandler(player);
    // Media notifications + lock-screen controls. Must run before playback
    // starts; the handler keeps the foreground service alive after the app is
    // swiped away from recents.
    await AudioService.init(
      builder: () => audioHandler!,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.monora.monora.playback',
        androidNotificationChannelName: 'Playback',
        androidNotificationChannelDescription:
            'Shows what Monora is playing, with transport controls.',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        notificationColor: Color(0xFFE5623D),
        artDownscaleWidth: 512,
        artDownscaleHeight: 512,
      ),
    );
  }

  final prefs = await SharedPreferences.getInstance();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFFF4EFE6),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioPlayerProvider.overrideWithValue(player),
        audioEqualizerProvider.overrideWithValue(equalizer),
        audioLoudnessEnhancerProvider.overrideWithValue(loudnessEnhancer),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const MonoraApp(),
    ),
  );
}
