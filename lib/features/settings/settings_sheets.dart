import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../app/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/library_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/player_providers.dart';
import '../../services/lastfm_service.dart';

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

// ---------------------------------------------------------------------------
// Crossfade
// ---------------------------------------------------------------------------

Future<void> showCrossfadeSheet(BuildContext context, WidgetRef ref) {
  final current = ref.read(crossfadeSecondsProvider);
  return showMonoraSheet(
    context,
    title: 'Crossfade Length',
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$current seconds',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Playfair',
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                  color: context.monora.ink,
                ),
              ),
              Slider(
                value: current.toDouble(),
                min: 1,
                max: 12,
                divisions: 11,
                activeColor: context.monora.accent,
                inactiveColor: context.monora.surfaceAlt,
                onChanged: (value) {
                  setSheetState(() {});
                  unawaited(
                    ref.read(crossfadeSecondsProvider.notifier).set(
                          value.round(),
                        ),
                  );
                },
              ),
              Text(
                'The current song fades out over its final seconds and the '
                'next one takes over. Works best with several songs queued.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  height: 1.45,
                  color: context.monora.inkSecondary,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Excluded folders
// ---------------------------------------------------------------------------

Future<void> showExcludedFoldersSheet(BuildContext context, WidgetRef ref) {
  return showMonoraSheet(
    context,
    title: 'Excluded Folders',
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, sheetRef, _) {
        final folders = sheetRef.watch(excludedFoldersProvider);
        final palette = sheetContext.monora;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Audio from these folders never appears in your library — '
                'perfect for recordings, ringtones and chat downloads.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  height: 1.45,
                  color: palette.inkSecondary,
                ),
              ),
            ),
            for (final folder in folders)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        folder,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 12.5,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => unawaited(
                        sheetRef
                            .read(excludedFoldersProvider.notifier)
                            .remove(folder),
                      ),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: palette.heart,
                      ),
                      tooltip: 'Include this folder again',
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Pressable(
                onTap: () async {
                  final result = await FilePickerPlatform.instance
                      .getDirectoryPath(
                        dialogTitle: 'Choose a folder to exclude',
                      );
                  if (result != null && sheetContext.mounted) {
                    await sheetRef
                        .read(excludedFoldersProvider.notifier)
                        .add(result);
                  }
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.ink,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Add folder to exclude',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: palette.background,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Playlist backup (export / import)
// ---------------------------------------------------------------------------

Future<void> showBackupSheet(BuildContext context, WidgetRef ref) {
  return showMonoraSheet(
    context,
    title: 'Backup & Restore',
    builder: (sheetContext) => Column(
      children: [
        _SheetOption(
          label: 'Export playlists to a file',
          selected: false,
          leading: Icon(
            Icons.file_upload_outlined,
            size: 20,
            color: sheetContext.monora.inkSecondary,
          ),
          onSelect: () async {
            Navigator.of(sheetContext).pop();
            await _exportPlaylists(context, ref);
          },
        ),
        _SheetOption(
          label: 'Import playlists from a backup',
          selected: false,
          leading: Icon(
            Icons.file_download_outlined,
            size: 20,
            color: sheetContext.monora.inkSecondary,
          ),
          onSelect: () async {
            Navigator.of(sheetContext).pop();
            await _importPlaylists(context, ref);
          },
        ),
      ],
    ),
  );
}

Future<void> _exportPlaylists(BuildContext context, WidgetRef ref) async {
  try {
    final playlists = ref.read(playlistsProvider);
    if (playlists.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No playlists to export yet.')),
        );
      }
      return;
    }
    final payload = jsonEncode({
      'app': 'monora',
      'version': 1,
      'playlists': [for (final p in playlists) p.toJson()],
    });
    final savedUri = await FilePickerPlatform.instance.saveFile(
      fileName: 'monora_playlists_backup.json',
      bytes: utf8.encode(payload),
      mimeType: 'application/json',
    );
    if (context.mounted && savedUri != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup saved.')),
      );
    }
  } on Exception {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed. Try again.')),
      );
    }
  }
}

Future<void> _importPlaylists(BuildContext context, WidgetRef ref) async {
  try {
    final files = await FilePickerPlatform.instance.pickFiles(
      type: FileType.any,
    );
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();
    final decoded = jsonDecode(utf8.decode(bytes));
    final rawList = decoded is Map<String, Object?>
        ? (decoded['playlists'] as List<Object?>?)
        : (decoded is List ? decoded : null);
    if (rawList == null) throw const FormatException('bad backup');
    final imported = [
      for (final raw in rawList.whereType<Map<String, Object?>>())
        MonoraPlaylist.fromJson(raw),
    ];
    final existing = ref.read(playlistsProvider);
    final existingIds = existing.map((p) => p.id).toSet();
    final existingNames = existing.map((p) => p.name.toLowerCase()).toSet();
    var added = 0;
    final notifier = ref.read(playlistsProvider.notifier);
    for (final playlist in imported) {
      if (existingIds.contains(playlist.id)) continue;
      var name = playlist.name;
      var suffix = 2;
      while (existingNames.contains(name.toLowerCase())) {
        name = '${playlist.name} ($suffix)';
        suffix++;
      }
      await notifier.create(name, trackIds: playlist.trackIds);
      existingNames.add(name.toLowerCase());
      added++;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'Nothing new to import — everything already exists.'
                : 'Imported $added '
                    '${added == 1 ? 'playlist' : 'playlists'}.',
          ),
        ),
      );
    }
  } on FormatException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That file is not a Monora backup.')),
      );
    }
  } on Exception {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import failed. Try again.')),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Last.fm scrobbling
// ---------------------------------------------------------------------------

Future<void> showLastFmSheet(BuildContext context, WidgetRef ref) {
  return showMonoraSheet(
    context,
    title: 'Last.fm',
    builder: (sheetContext) => const _LastFmSheet(),
  );
}

class _LastFmSheet extends ConsumerStatefulWidget {
  const _LastFmSheet();

  @override
  ConsumerState<_LastFmSheet> createState() => _LastFmSheetState();
}

class _LastFmSheetState extends ConsumerState<_LastFmSheet> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _signingIn = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_signingIn) return;
    setState(() {
      _signingIn = true;
      _error = null;
    });
    final sessionKey = await LastFmService.authenticate(
      _usernameController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _signingIn = false);
    if (sessionKey == null || sessionKey.isEmpty) {
      setState(
        () => _error = 'Could not sign in. Check your username and password.',
      );
      return;
    }
    await ref.read(lastFmSessionProvider.notifier).set(sessionKey);
    await ref.read(lastFmEnabledProvider.notifier).set(true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.monora;
    final session = ref.watch(lastFmSessionProvider);
    final enabled = ref.watch(lastFmEnabledProvider);

    if (!LastFmConfig.configured) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(
          'Scrobbling needs Last.fm API credentials. Create a free API '
          'account at last.fm/api/account/create and add the key and shared '
          'secret to LastFmConfig in lib/services/lastfm_service.dart.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
            fontSize: 12.5,
            height: 1.5,
            color: palette.inkSecondary,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (session.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: palette.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Signed in — scrobbling ready',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: palette.ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      unawaited(ref.read(lastFmSessionProvider.notifier).set('')),
                  child: Text('Sign out', style: TextStyle(color: palette.heart)),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: palette.accent,
              title: Text(
                'Scrobble what I play',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: palette.ink,
                ),
              ),
              value: enabled,
              onChanged: (value) =>
                  unawaited(ref.read(lastFmEnabledProvider.notifier).set(value)),
            ),
          ] else ...[
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(hintText: 'Last.fm username'),
              style: TextStyle(color: palette.ink, fontFamily: 'Inter'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Password'),
              style: TextStyle(color: palette.ink, fontFamily: 'Inter'),
              onSubmitted: (_) => unawaited(_signIn()),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: palette.heart,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Pressable(
              onTap: _signingIn ? null : _signIn,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.ink,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _signingIn
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(palette.background),
                        ),
                      )
                    : Text(
                        'Sign in to Last.fm',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: palette.background,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your password is only sent once, directly to Last.fm, to obtain '
              'a session key. Monora never stores it.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                fontSize: 11,
                height: 1.4,
                color: palette.inkTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
