import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Media notifications + lock-screen controls. Must run before any
  // AudioPlayer is constructed.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.monora.monora.playback',
    androidNotificationChannelName: 'Playback',
    androidNotificationChannelDescription:
        'Shows what Monora is playing, with transport controls.',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    notificationColor: const Color(0xFFE5623D),
    artDownscaleWidth: 512,
    artDownscaleHeight: 512,
  );

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
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MonoraApp(),
    ),
  );
}
