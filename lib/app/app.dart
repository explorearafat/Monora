import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/splash/splash_screens.dart';
import '../providers/app_providers.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

/// Root widget: resolves theme mode + accent from settings and hosts the app.
class MonoraApp extends ConsumerWidget {
  const MonoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentProvider);

    final resolvedMode = switch (themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

    return MaterialApp(
      title: 'Monora',
      debugShowCheckedModeBanner: false,
      theme: MonoraTheme.light(accent),
      darkTheme: MonoraTheme.dark(accent),
      themeMode: resolvedMode,
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: MonoraColors.cream,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: const SplashScreen(),
      ),
    );
  }
}
