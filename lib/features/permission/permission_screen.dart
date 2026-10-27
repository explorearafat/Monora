import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../providers/app_providers.dart';
import '../shell/shell_screen.dart';
import '../splash/splash_screens.dart' show WaveArtwork;

/// Explains why Monora needs audio access and walks the user through the
/// Android permission flow, including the permanently-denied dead end.
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  bool _requesting = false;

  Future<void> _request() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final status = await ref.read(permissionProvider.notifier).requestAudio();
    if (!mounted) return;
    setState(() => _requesting = false);
    if (status == LibraryPermissionStatus.granted) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, _, _) => const ShellScreen(),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  Future<void> _openSettings() async {
    await ref.read(permissionProvider.notifier).openSystemSettings();
    if (mounted) {
      await ref.read(permissionProvider.notifier).requestAudio();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    final permission = ref.watch(permissionProvider);

    final permanentlyDenied =
        permission.audio == LibraryPermissionStatus.permanentlyDenied;
    final denied = permission.audio == LibraryPermissionStatus.denied;

    final title = permanentlyDenied
        ? 'Access is turned off'
        : denied
        ? 'Let’s try that again'
        : 'Your music, private by design';
    final message = permanentlyDenied
        ? 'Monora was blocked from reading audio files. Re-enable access in system settings to let it find your songs.'
        : denied
        ? 'Monora still needs access to play the music stored on this device. Nothing leaves your phone.'
        : 'Monora plays the music already on your device. Allow access to audio files so it can find your library — nothing is uploaded, ever.';

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: WaveArtwork.static()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    const MonoraLogo(size: 84),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Playfair',
                        fontWeight: FontWeight.w600,
                        fontSize: 26,
                        height: 1.2,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        height: 1.55,
                        color: palette.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _PermissionBullet(
                      icon: Icons.library_music_rounded,
                      text: 'Scans your local MP3, FLAC, WAV and AAC files',
                    ),
                    const SizedBox(height: 10),
                    _PermissionBullet(
                      icon: Icons.lock_rounded,
                      text: 'Works fully offline — no account, no uploads',
                    ),
                    const SizedBox(height: 36),
                    Pressable(
                      borderRadius: BorderRadius.circular(28),
                      onTap: permanentlyDenied ? _openSettings : _request,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: _requesting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation(
                                    palette.onAccent,
                                  ),
                                ),
                              )
                            : Text(
                                permanentlyDenied
                                    ? 'Open Settings'
                                    : 'Allow audio access',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: palette.onAccent,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionBullet extends StatelessWidget {
  const _PermissionBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: palette.surface,
            shape: BoxShape.circle,
            border: Border.all(color: palette.outline),
          ),
          child: Icon(icon, size: 17, color: palette.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: palette.inkSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
