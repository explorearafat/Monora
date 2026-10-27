import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

/// Custom route builders so navigation feels like one motion system:
/// * detail screens (album, artist, playlist, lyrics) slide in from the right
///   with a soft fade,
/// * the Now Playing surfaces from the bottom, like a sheet taking over.
Future<T?> pushDetail<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push(
    PageRouteBuilder<T>(
      transitionDuration: MonoraMotion.page,
      reverseTransitionDuration: MonoraMotion.page,
      pageBuilder: (_, _, _) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: MonoraMotion.emphasized,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

Future<T?> pushImmersive<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push(
    PageRouteBuilder<T>(
      opaque: false,
      transitionDuration: MonoraMotion.page,
      reverseTransitionDuration: MonoraMotion.page,
      pageBuilder: (_, _, _) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: MonoraMotion.emphasized,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}
