import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/library_models.dart';

/// User-scoped data persisted locally: favorites, recently played, play
/// counts, listening stats, playlists, and settings.
class PreferencesRepository {
  PreferencesRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyFavorites = 'monora.favorites';
  static const _keyRecents = 'monora.recent_tracks';
  static const _keyPlayCounts = 'monora.play_counts';
  static const _keyListeningSeconds = 'monora.listening_seconds';
  static const _keyPlaylists = 'monora.playlists';
  static const _keyProfileName = 'monora.profile_name';
  static const _keyThemeMode = 'monora.theme_mode';
  static const _keyAccent = 'monora.accent';
  static const _keyPauseOnInterruptions = 'monora.pause_on_interruptions';
  static const _keyResumeSession = 'monora.resume_session';
  static const _keyPlaybackSpeed = 'monora.playback_speed';
  static const _keyLastSession = 'monora.last_session';

  // --- Favorites -----------------------------------------------------------

  Set<int> loadFavoriteIds() =>
      _prefs.getStringList(_keyFavorites)?.map(int.parse).toSet() ?? <int>{};

  Future<void> saveFavoriteIds(Set<int> ids) =>
      _prefs.setStringList(_keyFavorites, ids.map((id) => '$id').toList());

  // --- Recently played -----------------------------------------------------

  List<int> loadRecentTrackIds() =>
      _prefs.getStringList(_keyRecents)?.map(int.parse).toList() ?? <int>[];

  Future<void> saveRecentTrackIds(List<int> ids) =>
      _prefs.setStringList(_keyRecents, ids.map((id) => '$id').toList());

  // --- Play counts ---------------------------------------------------------

  Map<int, int> loadPlayCounts() {
    final raw = _prefs.getString(_keyPlayCounts);
    if (raw == null) return <int, int>{};
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    return decoded.map(
      (key, value) => MapEntry(int.parse(key), (value as num).toInt()),
    );
  }

  Future<void> savePlayCounts(Map<int, int> counts) => _prefs.setString(
    _keyPlayCounts,
    jsonEncode(counts.map((key, value) => MapEntry('$key', value))),
  );

  // --- Listening time ------------------------------------------------------

  int loadListeningSeconds() => _prefs.getInt(_keyListeningSeconds) ?? 0;

  Future<void> saveListeningSeconds(int seconds) =>
      _prefs.setInt(_keyListeningSeconds, seconds);

  // --- Playlists -----------------------------------------------------------

  List<MonoraPlaylist> loadPlaylists() {
    final raw = _prefs.getString(_keyPlaylists);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<Object?>;
    return decoded
        .whereType<Map<String, Object?>>()
        .map(MonoraPlaylist.fromJson)
        .toList();
  }

  Future<void> savePlaylists(List<MonoraPlaylist> playlists) =>
      _prefs.setString(
        _keyPlaylists,
        jsonEncode([for (final playlist in playlists) playlist.toJson()]),
      );

  // --- Profile -------------------------------------------------------------

  String loadProfileName() =>
      _prefs.getString(_keyProfileName) ?? 'Music Lover';

  Future<void> saveProfileName(String name) =>
      _prefs.setString(_keyProfileName, name);

  // --- Settings ------------------------------------------------------------

  String loadThemeMode() => _prefs.getString(_keyThemeMode) ?? 'system';

  Future<void> saveThemeMode(String mode) =>
      _prefs.setString(_keyThemeMode, mode);

  String loadAccentName() => _prefs.getString(_keyAccent) ?? 'Orange';

  Future<void> saveAccentName(String name) =>
      _prefs.setString(_keyAccent, name);

  bool loadPauseOnInterruptions() =>
      _prefs.getBool(_keyPauseOnInterruptions) ?? true;

  Future<void> savePauseOnInterruptions(bool value) =>
      _prefs.setBool(_keyPauseOnInterruptions, value);

  bool loadResumeSession() => _prefs.getBool(_keyResumeSession) ?? true;

  Future<void> saveResumeSession(bool value) =>
      _prefs.setBool(_keyResumeSession, value);

  double loadPlaybackSpeed() => _prefs.getDouble(_keyPlaybackSpeed) ?? 1.0;

  Future<void> savePlaybackSpeed(double speed) =>
      _prefs.setDouble(_keyPlaybackSpeed, speed);

  // --- Last session (queue snapshot) ---------------------------------------

  LastSessionSnapshot? loadLastSession() {
    final raw = _prefs.getString(_keyLastSession);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      return LastSessionSnapshot.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> saveLastSession(LastSessionSnapshot? snapshot) async {
    if (snapshot == null || snapshot.trackIds.isEmpty) {
      await _prefs.remove(_keyLastSession);
      return;
    }
    await _prefs.setString(_keyLastSession, jsonEncode(snapshot.toJson()));
  }
}

/// A persisted queue snapshot enabling "Resume Last Session".
class LastSessionSnapshot {
  const LastSessionSnapshot({
    required this.trackIds,
    required this.trackIndex,
    required this.positionMs,
    required this.shuffle,
    required this.loopModeIndex,
  });

  final List<int> trackIds;
  final int trackIndex;
  final int positionMs;
  final bool shuffle;
  final int loopModeIndex;

  Map<String, Object?> toJson() => {
    'trackIds': trackIds,
    'trackIndex': trackIndex,
    'positionMs': positionMs,
    'shuffle': shuffle,
    'loopModeIndex': loopModeIndex,
  };

  static LastSessionSnapshot fromJson(Map<String, Object?> json) {
    return LastSessionSnapshot(
      trackIds: ((json['trackIds'] as List<Object?>?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(growable: false),
      trackIndex: (json['trackIndex'] as num?)?.toInt() ?? 0,
      positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
      shuffle: (json['shuffle'] as bool?) ?? false,
      loopModeIndex: (json['loopModeIndex'] as num?)?.toInt() ?? 0,
    );
  }
}
