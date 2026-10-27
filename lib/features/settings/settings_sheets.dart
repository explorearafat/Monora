import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../app/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../providers/app_providers.dart';
import '../../providers/player_providers.dart';

/// Opens the system sound settings so the user can pick a real output device.
const MethodChannel _systemChannel = MethodChannel('monora/system');

Future<void> openSystemSoundSettings() async {
  try {
    await _systemChannel.invokeMethod<void>('openSoundSettings');
  } on PlatformException {
    // Nothing sensible to do if the platform doesn't support it.
  }
}

Future<T?> showMonoraSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  final palette = context.monora;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Playfair',
                fontWeight: FontWeight.w600,
                fontSize: 19,
                color: palette.ink,
              ),
            ),
          ),
          const SizedBox(height: 6),
          builder(sheetContext),
          const SizedBox(height: 14),
        ],
      ),
    ),
  );
}

class _SheetOption<T> extends StatelessWidget {
  const _SheetOption({
    required this.label,
    required this.selected,
    required this.onSelect,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Pressable(
      onTap: onSelect,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
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
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: palette.accent),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme + accent
// ---------------------------------------------------------------------------

Future<void> showThemeSheet(BuildContext context, WidgetRef ref) {
  return showMonoraSheet(
    context,
    title: 'Theme',
    builder: (sheetContext) => Column(
      children: [
        for (final mode in AppThemeMode.values)
          _SheetOption(
            label: mode.label,
            selected: ref.read(themeModeProvider) == mode,
            onSelect: () {
              ref.read(themeModeProvider.notifier).setMode(mode);
              Navigator.of(sheetContext).pop();
            },
          ),
      ],
    ),
  );
}

Future<void> showAccentSheet(BuildContext context, WidgetRef ref) {
  return showMonoraSheet(
    context,
    title: 'Accent Color',
    builder: (sheetContext) => Column(
      children: [
        for (final option in MonoraColors.accentOptions)
          _SheetOption(
            label: option.name,
            selected: ref.read(accentProvider).name == option.name,
            leading: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: option.primary,
                shape: BoxShape.circle,
              ),
              child: ref.read(accentProvider).name == option.name
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            onSelect: () {
              ref.read(accentProvider.notifier).setAccent(option);
              Navigator.of(sheetContext).pop();
            },
          ),
      ],
    ),
  );
}

Future<void> showLanguageSheet(BuildContext context, WidgetRef ref) {
  return showMonoraSheet(
    context,
    title: 'Language',
    builder: (sheetContext) => Column(
      children: [
        _SheetOption(
          label: 'English',
          selected: true,
          onSelect: () => Navigator.of(sheetContext).pop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            'More languages may arrive in a future update.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 12,
              color: context.monora.inkTertiary,
            ),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Playback speed + sleep timer
// ---------------------------------------------------------------------------

const _speedChoices = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

Future<void> showSpeedSheet(BuildContext context, WidgetRef ref) {
  final current = ref.read(playbackSpeedProvider);
  return showMonoraSheet(
    context,
    title: 'Playback Speed',
    builder: (sheetContext) => Column(
      children: [
        for (final speed in _speedChoices)
          _SheetOption(
            label: '${speed}x',
            selected: (current - speed).abs() < 0.001,
            onSelect: () {
              ref.read(playbackSpeedProvider.notifier).set(speed);
              unawaited(ref.read(playerServiceProvider).setSpeed(speed));
              Navigator.of(sheetContext).pop();
            },
          ),
      ],
    ),
  );
}

const _sleepChoices = [
  (Duration(minutes: 5), '5 minutes'),
  (Duration(minutes: 15), '15 minutes'),
  (Duration(minutes: 30), '30 minutes'),
  (Duration(minutes: 45), '45 minutes'),
  (Duration(minutes: 60), '1 hour'),
];

Future<void> showSleepTimerSheet(BuildContext context, WidgetRef ref) {
  final player = ref.read(playerServiceProvider);
  return showMonoraSheet(
    context,
    title: 'Sleep Timer',
    builder: (sheetContext) => Column(
      children: [
        if (player.sleepTimerActive)
          _SheetOption(
            label:
                'Cancel timer (${player.sleepRemaining.value.inMinutes} min left)',
            selected: false,
            leading: Icon(
              Icons.timer_off_rounded,
              size: 20,
              color: context.monora.heart,
            ),
            onSelect: () {
              player.cancelSleepTimer();
              Navigator.of(sheetContext).pop();
            },
          ),
        for (final (duration, label) in _sleepChoices)
          _SheetOption(
            label: label,
            selected: false,
            leading: Icon(
              Icons.nightlight_round,
              size: 19,
              color: context.monora.inkSecondary,
            ),
            onSelect: () {
              player.startSleepTimer(duration);
              Navigator.of(sheetContext).pop();
            },
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Equalizer
// ---------------------------------------------------------------------------

Future<void> showEqualizerSheet(BuildContext context, WidgetRef ref) {
  return showMonoraSheet(
    context,
    title: 'Equalizer',
    builder: (sheetContext) => const _EqualizerSheet(),
  );
}

class _EqualizerSheet extends ConsumerStatefulWidget {
  const _EqualizerSheet();

  @override
  ConsumerState<_EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends ConsumerState<_EqualizerSheet> {
  AndroidEqualizerParameters? _parameters;
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _loadParameters();
  }

  Future<void> _loadParameters() async {
    final equalizer = ref.read(playerServiceProvider).equalizer;
    if (equalizer == null) return;
    try {
      final parameters = await equalizer.parameters;
      if (mounted) {
        setState(() {
          _parameters = parameters;
          _enabled = equalizer.enabled;
        });
      }
    } on Exception {
      if (mounted) setState(() => _parameters = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    final equalizer = ref.watch(
      playerServiceProvider.select((p) => p.equalizer),
    );

    if (equalizer == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'The equalizer is only available while playing on Android devices.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 13.5,
            height: 1.45,
            color: palette.inkSecondary,
          ),
        ),
      );
    }
    if (_parameters == null) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final parameters = _parameters!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Enable equalizer',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: palette.ink,
                  ),
                ),
              ),
              Switch(
                value: _enabled ?? false,
                onChanged: (value) {
                  setState(() => _enabled = value);
                  unawaited(equalizer.setEnabled(value));
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final band in parameters.bands)
            _BandSlider(
              band: band,
              min: parameters.minDecibels,
              max: parameters.maxDecibels,
            ),
          Text(
            'Applies to Android playback. Gains range '
            '${parameters.minDecibels.toStringAsFixed(0)} to '
            '+${parameters.maxDecibels.toStringAsFixed(0)} dB.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
              fontSize: 11.5,
              color: palette.inkTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  const _BandSlider({required this.band, required this.min, required this.max});

  final AndroidEqualizerBand band;
  final double min;
  final double max;

  String get _label {
    final hz = band.centerFrequency;
    if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(1)} kHz';
    return '${hz.round()} Hz';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            _label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 11.5,
              color: palette.inkSecondary,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<double>(
            stream: band.gainStream,
            initialData: band.gain,
            builder: (context, snapshot) {
              final gain = snapshot.data ?? band.gain;
              return Slider(
                value: gain.clamp(min, max),
                min: min,
                max: max,
                activeColor: palette.accent,
                inactiveColor: palette.surfaceAlt,
                thumbColor: palette.accent,
                onChanged: (value) => band.setGain(value),
              );
            },
          ),
        ),
        SizedBox(
          width: 46,
          child: StreamBuilder<double>(
            stream: band.gainStream,
            initialData: band.gain,
            builder: (context, snapshot) {
              final gain = snapshot.data ?? band.gain;
              return Text(
                '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 11.5,
                  color: palette.inkTertiary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
