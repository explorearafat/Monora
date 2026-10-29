import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/widgets/common.dart';
import '../../providers/app_providers.dart';
import '../../providers/player_providers.dart';
import '../../services/lastfm_service.dart';
import 'settings_sheets.dart';

/// Settings: Appearance, Playback, Audio — every control is wired to a real
/// behavior (theme, accent, interruption handling, speed, sleep timer,
/// equalizer, output routing).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.monora;
    final text = MonoraText.of(palette);
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentProvider);
    final pauseOnInterruptions = ref.watch(pauseOnInterruptionsProvider);
    final resumeSession = ref.watch(resumeSessionProvider);
    final speed = ref.watch(playbackSpeedProvider);
    final crossfade = ref.watch(crossfadeProvider);
    final crossfadeSeconds = ref.watch(crossfadeSecondsProvider);
    final skipSilence = ref.watch(skipSilenceProvider);
    final excludedFolders = ref.watch(excludedFoldersProvider);
    final lastFmEnabled = ref.watch(lastFmEnabledProvider);
    final lastFmSession = ref.watch(lastFmSessionProvider);
    final player = ref.watch(playerServiceProvider);
    final Widget sleepValue = ValueListenableBuilder<Duration>(
      valueListenable: player.sleepRemaining,
      builder: (context, remaining, _) {
        return Text(
          player.sleepTimerActive
              ? '${remaining.inMinutes} min ${remaining.inSeconds % 60} sec left'
              : 'Off',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: palette.inkSecondary,
          ),
        );
      },
    );

    // Keep the audio-focus behavior in sync with the setting.
    ref.listen(pauseOnInterruptionsProvider, (_, next) {
      ref.read(playerServiceProvider).setPauseOnInterruptions(next);
    });

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          tooltip: 'Back',
        ),
        title: Text('Settings', style: text.screenTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 28),
        children: [
          _SectionLabel('Appearance'),
          _SettingsRow(
            icon: Icons.dark_mode_outlined,
            label: 'Theme',
            value: themeMode.label,
            onTap: () => showThemeSheet(context, ref),
          ),
          _SettingsRow(
            icon: Icons.palette_outlined,
            label: 'Accent Color',
            valueWidget: _AccentDot(color: accent.primary),
            trailing: accent.name,
            onTap: () => showAccentSheet(context, ref),
          ),
          _SettingsRow(
            icon: Icons.translate_rounded,
            label: 'Language',
            value: 'English',
            onTap: () => showLanguageSheet(context, ref),
          ),
          const SizedBox(height: 18),
          _SectionLabel('Playback'),
          _SettingsToggleRow(
            icon: Icons.notifications_paused_rounded,
            label: 'Pause on Interruptions',
            value: pauseOnInterruptions,
            onChanged: (value) => unawaited(
              ref.read(pauseOnInterruptionsProvider.notifier).set(value),
            ),
          ),
          _SettingsToggleRow(
            icon: Icons.restore_rounded,
            label: 'Resume Last Session',
            value: resumeSession,
            onChanged: (value) =>
                unawaited(ref.read(resumeSessionProvider.notifier).set(value)),
          ),
          _SettingsRow(
            icon: Icons.speed_rounded,
            label: 'Playback Speed',
            value: '${speed}x',
            onTap: () => showSpeedSheet(context, ref),
          ),
          _SettingsRow(
            icon: Icons.bedtime_rounded,
            label: 'Sleep Timer',
            valueWidget: sleepValue,
            onTap: () => showSleepTimerSheet(context, ref),
          ),
          _SettingsToggleRow(
            icon: Icons.auto_fix_high_rounded,
            label: 'Crossfade',
            value: crossfade,
            onChanged: (value) => unawaited(
              ref.read(crossfadeProvider.notifier).set(value),
            ),
          ),
          if (crossfade)
            _SettingsRow(
              icon: Icons.av_timer_rounded,
              label: 'Crossfade Length',
              value: '$crossfadeSeconds seconds',
              onTap: () => showCrossfadeSheet(context, ref),
            ),
          _SettingsToggleRow(
            icon: Icons.graphic_eq_rounded,
            label: 'Skip Silence',
            value: skipSilence,
            onChanged: (value) => unawaited(
              ref.read(skipSilenceProvider.notifier).set(value),
            ),
          ),
          const SizedBox(height: 18),
          _SectionLabel('Audio'),
          _SettingsRow(
            icon: Icons.equalizer_rounded,
            label: 'Equalizer',
            value: player.equalizerSupported ? 'Custom' : 'Unavailable',
            onTap: () => showEqualizerSheet(context, ref),
          ),
          _SettingsRow(
            icon: Icons.speaker_rounded,
            label: 'Audio Output',
            value: 'Device Default',
            onTap: openSystemSoundSettings,
          ),
          const SizedBox(height: 18),
          _SectionLabel('Library & Data'),
          _SettingsRow(
            icon: Icons.folder_off_rounded,
            label: 'Excluded Folders',
            value: excludedFolders.isEmpty
                ? 'None'
                : '${excludedFolders.length} '
                    '${excludedFolders.length == 1 ? 'folder' : 'folders'}',
            onTap: () => showExcludedFoldersSheet(context, ref),
          ),
          _SettingsRow(
            icon: Icons.backup_outlined,
            label: 'Backup & Restore',
            value: 'Playlists',
            onTap: () => showBackupSheet(context, ref),
          ),
          const SizedBox(height: 18),
          if (LastFmConfig.configured) ...[
            _SectionLabel('Connect'),
            _SettingsRow(
              icon: Icons.audiotrack_rounded,
              label: 'Last.fm Scrobbling',
              value: lastFmEnabled
                  ? 'On'
                  : lastFmSession.isNotEmpty
                  ? 'Signed in'
                  : 'Off',
              onTap: () => showLastFmSheet(context, ref),
            ),
            const SizedBox(height: 18),
          ],
          const SizedBox(height: 26),
          Center(
            child: Text(
              'Monora 1.0.1 · Your sound. Your space.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 11.5,
                color: palette.inkTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 1.1,
          color: palette.inkTertiary,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.valueWidget,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;
  final Widget? valueWidget;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: palette.outline),
              ),
              child: Icon(icon, size: 18, color: palette.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 14.5,
                  color: palette.ink,
                ),
              ),
            ),
            if (valueWidget != null) ...[
              valueWidget!,
              const SizedBox(width: 8),
            ],
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: palette.inkSecondary,
                ),
              )
            else if (value != null)
              Text(
                value!,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: palette.inkSecondary,
                ),
              ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: palette.inkTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              border: Border.all(color: palette.outline),
            ),
            child: Icon(icon, size: 18, color: palette.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14.5,
                color: palette.ink,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
