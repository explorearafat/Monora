import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme/app_colors.dart';
import '../data/models/library_models.dart';
import '../data/repositories/artwork_repository.dart';
import '../data/repositories/lyrics_repository.dart';
import '../data/repositories/media_repository.dart';
import '../data/repositories/preferences_repository.dart';

// Circular by design: settings notifiers need the player service to apply
// skip-silence/crossfade changes, while player_providers consumes the
// repositories declared here.
import 'player_providers.dart';
/// Injected at bootstrap in `main()` so every repository can be synchronous.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden at bootstrap',
  ),
);

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepository(ref.watch(sharedPreferencesProvider)),
);

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => OnAudioQueryMediaRepository(),
);

final artworkRepositoryProvider = Provider<ArtworkRepository>(
  (ref) => ArtworkRepository(ref.watch(mediaRepositoryProvider)),
);

final lyricsRepositoryProvider = Provider<LyricsRepository>(
  (ref) => LyricsRepository(),
);

// ---------------------------------------------------------------------------
// Permissions
// ---------------------------------------------------------------------------

enum LibraryPermissionStatus {
  undetermined,
  granted,
  denied,
  permanentlyDenied,
}

class PermissionState {
  const PermissionState({
    required this.audio,
    this.notifications = LibraryPermissionStatus.undetermined,
  });

  final LibraryPermissionStatus audio;
  final LibraryPermissionStatus notifications;

  bool get canReadLibrary => audio == LibraryPermissionStatus.granted;

  PermissionState copyWith({
    LibraryPermissionStatus? audio,
    LibraryPermissionStatus? notifications,
  }) {
    return PermissionState(
      audio: audio ?? this.audio,
      notifications: notifications ?? this.notifications,
    );
  }
}

class PermissionNotifier extends Notifier<PermissionState> {
  @override
  PermissionState build() {
    Future.microtask(refresh);
    return const PermissionState(audio: LibraryPermissionStatus.undetermined);
  }

  /// Re-reads the OS permission state. Await this before making routing
  /// decisions — the splash screen must never race the platform channel.
  Future<void> refresh() async {
    try {
      final status = await Permission.audio.status;
      state = state.copyWith(audio: _map(status));
    } on Exception {
      // Platform channel hiccup — leave as undetermined so the permission
      // screen still renders and the user can tap "Allow audio access".
    }
  }

  LibraryPermissionStatus _map(PermissionStatus status) => switch (status) {
    PermissionStatus.granted ||
    PermissionStatus.limited => LibraryPermissionStatus.granted,
    PermissionStatus.permanentlyDenied ||
    PermissionStatus.restricted => LibraryPermissionStatus.permanentlyDenied,
    PermissionStatus.denied => LibraryPermissionStatus.denied,
    _ => LibraryPermissionStatus.undetermined,
  };

  /// Requests audio access. Returns the resulting library-readiness.
  Future<LibraryPermissionStatus> requestAudio() async {
    var status = LibraryPermissionStatus.denied;
    try {
      var result = await Permission.audio.request();
      if (result.isDenied) {
        // Some Android 12- devices surface storage instead of audio.
        result = await Permission.storage.request();
      }
      status = _map(result);
    } on Exception {
      return LibraryPermissionStatus.denied;
    }
    state = state.copyWith(audio: status);

    // One-time ask for the media notification (Android 13+). Only prompted
    // after audio access exists, and only while still undetermined so the
    // dialog can never loop across launches.
    if (status == LibraryPermissionStatus.granted &&
        state.notifications == LibraryPermissionStatus.undetermined) {
      await requestNotifications();
    }
    return state.audio;
  }

  Future<void> requestNotifications() async {
    try {
      final status = await Permission.notification.request();
      state = state.copyWith(notifications: _map(status));
    } on Exception {
      // Notifications are optional.
    }
  }

  Future<void> openSystemSettings() => openAppSettings();
}

final permissionProvider =
    NotifierProvider<PermissionNotifier, PermissionState>(
      PermissionNotifier.new,
    );

// ---------------------------------------------------------------------------
// Library
// ---------------------------------------------------------------------------

/// Everything the device library scan produces, loaded as one unit so screens
/// never mix partially refreshed collections.
class LibraryData {
  const LibraryData({
    required this.tracks,
    required this.albums,
    required this.artists,
    required this.genres,
    required this.scannedAt,
  });

  final List<Track> tracks;
  final List<Album> albums;
  final List<Artist> artists;
  final List<GenreStat> genres;
  final DateTime? scannedAt;

  static const empty = LibraryData(
    tracks: [],
    albums: [],
    artists: [],
    genres: [],
    scannedAt: null,
  );

  bool get isEmpty => tracks.isEmpty;
}

class LibraryNotifier extends AsyncNotifier<LibraryData> {
  @override
  Future<LibraryData> build() async {
    final repository = ref.watch(mediaRepositoryProvider);
    final excluded = ref.watch(excludedFoldersProvider);
    final allTracks = await repository.loadTracks();
    // Filtered at the track level, then albums/artists/genres are derived
    // from the surviving tracks so excluded folders disappear everywhere.
    final tracks = [
      for (final track in allTracks)
        if (!isExcluded(track.file, excluded)) track,
    ];
    return LibraryData(
      tracks: tracks,
      albums: albumsFromTracks(tracks),
      artists: artistsFromTracks(tracks),
      genres: genresFromTracks(tracks),
      scannedAt: DateTime.now(),
    );
  }

  Future<void> rescan() async {
    state = const AsyncLoading<LibraryData>();
    state = await AsyncValue.guard(() => build());
  }
}

final libraryProvider = AsyncNotifierProvider<LibraryNotifier, LibraryData>(
  LibraryNotifier.new,
);

/// Quick id → track lookup used by favorites/recents/playlist resolution.
final tracksByIdProvider = Provider<Map<int, Track>>((ref) {
  final library = ref.watch(libraryProvider).value ?? LibraryData.empty;
  return {for (final track in library.tracks) track.id: track};
});

// ---------------------------------------------------------------------------
// Favorites
// ---------------------------------------------------------------------------

class FavoritesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() =>
      ref.watch(preferencesRepositoryProvider).loadFavoriteIds().toSet();

  Future<void> toggle(int trackId) async {
    final next = Set<int>.of(state);
    if (!next.remove(trackId)) {
      next.add(trackId);
    }
    state = next;
    await ref.read(preferencesRepositoryProvider).saveFavoriteIds(next);
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<int>>(
  FavoritesNotifier.new,
);

// ---------------------------------------------------------------------------
// Recently played
// ---------------------------------------------------------------------------

class RecentsNotifier extends Notifier<List<int>> {
  static const int maxEntries = 24;

  @override
  List<int> build() =>
      ref.watch(preferencesRepositoryProvider).loadRecentTrackIds();

  Future<void> record(int trackId) async {
    final next = List<int>.of(state)..remove(trackId);
    next.insert(0, trackId);
    if (next.length > maxEntries) {
      next.removeRange(maxEntries, next.length);
    }
    state = next;
    await ref.read(preferencesRepositoryProvider).saveRecentTrackIds(next);
  }
}

final recentsProvider = NotifierProvider<RecentsNotifier, List<int>>(
  RecentsNotifier.new,
);

/// Recently played resolved to tracks, skipping ids no longer in the library.
final recentTracksProvider = Provider<List<Track>>((ref) {
  final ids = ref.watch(recentsProvider);
  final byId = ref.watch(tracksByIdProvider);
  return [
    for (final id in ids)
      if (byId.containsKey(id)) byId[id]!,
  ];
});

/// Tracks currently marked as favorites, in library order.
final favoriteTracksProvider = Provider<List<Track>>((ref) {
  final ids = ref.watch(favoritesProvider);
  final library = ref.watch(libraryProvider).value ?? LibraryData.empty;
  return [
    for (final track in library.tracks)
      if (ids.contains(track.id)) track,
  ];
});

// ---------------------------------------------------------------------------
// Play counts
// ---------------------------------------------------------------------------

class PlayCountsNotifier extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() =>
      ref.watch(preferencesRepositoryProvider).loadPlayCounts();

  Future<void> increment(int trackId) async {
    final next = Map<int, int>.of(state);
    next[trackId] = (next[trackId] ?? 0) + 1;
    state = next;
    await ref.read(preferencesRepositoryProvider).savePlayCounts(next);
  }
}

final playCountsProvider = NotifierProvider<PlayCountsNotifier, Map<int, int>>(
  PlayCountsNotifier.new,
);

// ---------------------------------------------------------------------------
// Playlists
// ---------------------------------------------------------------------------

class PlaylistsNotifier extends Notifier<List<MonoraPlaylist>> {
  @override
  List<MonoraPlaylist> build() =>
      ref.watch(preferencesRepositoryProvider).loadPlaylists();

  Future<void> _persist(List<MonoraPlaylist> playlists) async {
    state = playlists;
    await ref.read(preferencesRepositoryProvider).savePlaylists(playlists);
  }

  Future<MonoraPlaylist> create(
    String name, {
    List<int> trackIds = const [],
  }) async {
    final playlist = MonoraPlaylist(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: name.trim().isEmpty ? 'New Playlist' : name.trim(),
      trackIds: List.of(trackIds),
      createdAt: DateTime.now(),
    );
    await _persist([...state, playlist]);
    return playlist;
  }

  Future<void> rename(String playlistId, String name) async {
    await _persist([
      for (final playlist in state)
        if (playlist.id == playlistId)
          playlist.copyWith(
            name: name.trim().isEmpty ? playlist.name : name.trim(),
          )
        else
          playlist,
    ]);
  }

  Future<void> delete(String playlistId) async {
    await _persist([
      for (final playlist in state)
        if (playlist.id != playlistId) playlist,
    ]);
  }

  Future<void> addTrack(String playlistId, int trackId) async {
    await _persist([
      for (final playlist in state)
        if (playlist.id == playlistId && !playlist.trackIds.contains(trackId))
          playlist.copyWith(trackIds: [...playlist.trackIds, trackId])
        else
          playlist,
    ]);
  }

  Future<void> removeTrack(String playlistId, int trackId) async {
    await _persist([
      for (final playlist in state)
        if (playlist.id == playlistId)
          playlist.copyWith(
            trackIds: playlist.trackIds.where((id) => id != trackId).toList(),
          )
        else
          playlist,
    ]);
  }

  Future<void> reorderTracks(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    await _persist([
      for (final playlist in state)
        if (playlist.id == playlistId)
          playlist.copyWith(
            trackIds: _reorder(playlist.trackIds, oldIndex, newIndex),
          )
        else
          playlist,
    ]);
  }

  static List<int> _reorder(List<int> ids, int oldIndex, int newIndex) {
    final next = List<int>.of(ids);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), item);
    return next;
  }
}

final playlistsProvider =
    NotifierProvider<PlaylistsNotifier, List<MonoraPlaylist>>(
      PlaylistsNotifier.new,
    );

/// Resolves a playlist's track ids against the library (skips deleted files).
final playlistTracksFamily = Provider.family<List<Track>, MonoraPlaylist>((
  ref,
  playlist,
) {
  final byId = ref.watch(tracksByIdProvider);
  return [
    for (final id in playlist.trackIds)
      if (byId.containsKey(id)) byId[id]!,
  ];
});

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

enum AppThemeMode { system, light, dark }

extension AppThemeModeX on AppThemeMode {
  String get label => switch (this) {
    AppThemeMode.system => 'System',
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
  };
}

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final raw = ref.watch(preferencesRepositoryProvider).loadThemeMode();
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    await ref.read(preferencesRepositoryProvider).saveThemeMode(mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);

class AccentNotifier extends Notifier<AccentOption> {
  @override
  AccentOption build() {
    final name = ref.watch(preferencesRepositoryProvider).loadAccentName();
    return MonoraColors.accentOptions.firstWhere(
      (option) => option.name == name,
      orElse: () => MonoraColors.accentOptions.first,
    );
  }

  Future<void> setAccent(AccentOption option) async {
    state = option;
    await ref.read(preferencesRepositoryProvider).saveAccentName(option.name);
  }
}

final accentProvider = NotifierProvider<AccentNotifier, AccentOption>(
  AccentNotifier.new,
);

class PauseOnInterruptionsNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(preferencesRepositoryProvider).loadPauseOnInterruptions();

  Future<void> set(bool value) async {
    state = value;
    await ref
        .read(preferencesRepositoryProvider)
        .savePauseOnInterruptions(value);
  }
}

final pauseOnInterruptionsProvider =
    NotifierProvider<PauseOnInterruptionsNotifier, bool>(
      PauseOnInterruptionsNotifier.new,
    );

class ResumeSessionNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(preferencesRepositoryProvider).loadResumeSession();

  Future<void> set(bool value) async {
    state = value;
    await ref.read(preferencesRepositoryProvider).saveResumeSession(value);
  }
}

final resumeSessionProvider = NotifierProvider<ResumeSessionNotifier, bool>(
  ResumeSessionNotifier.new,
);

class PlaybackSpeedNotifier extends Notifier<double> {
  @override
  double build() =>
      ref.watch(preferencesRepositoryProvider).loadPlaybackSpeed();

  Future<void> set(double speed) async {
    state = speed;
    await ref.read(preferencesRepositoryProvider).savePlaybackSpeed(speed);
  }
}

final playbackSpeedProvider = NotifierProvider<PlaybackSpeedNotifier, double>(
  PlaybackSpeedNotifier.new,
);

/// Index into the track sort options shown on track-list screens.
class TrackSortNotifier extends Notifier<int> {
  @override
  int build() => ref.watch(preferencesRepositoryProvider).loadTrackSort();

  Future<void> set(int index) async {
    state = index;
    await ref.read(preferencesRepositoryProvider).saveTrackSort(index);
  }
}

final trackSortProvider = NotifierProvider<TrackSortNotifier, int>(
  TrackSortNotifier.new,
);

class ExcludedFoldersNotifier extends Notifier<List<String>> {
  @override
  List<String> build() =>
      ref.watch(preferencesRepositoryProvider).loadExcludedFolders();

  Future<void> add(String folder) async {
    if (state.any((existing) => existing == folder)) return;
    final next = [...state, folder]..sort();
    state = next;
    await ref.read(preferencesRepositoryProvider).saveExcludedFolders(next);
    // libraryProvider watches this notifier, so the scan refreshes itself.
  }

  Future<void> remove(String folder) async {
    final next = state.where((existing) => existing != folder).toList();
    state = next;
    await ref.read(preferencesRepositoryProvider).saveExcludedFolders(next);
  }
}

final excludedFoldersProvider =
    NotifierProvider<ExcludedFoldersNotifier, List<String>>(
      ExcludedFoldersNotifier.new,
    );

class SkipSilenceNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(preferencesRepositoryProvider).loadSkipSilence();

  Future<void> set(bool value) async {
    state = value;
    await ref.read(preferencesRepositoryProvider).saveSkipSilence(value);
    await ref.read(playerServiceProvider).setSkipSilence(value);
  }
}

final skipSilenceProvider = NotifierProvider<SkipSilenceNotifier, bool>(
  SkipSilenceNotifier.new,
);

class CrossfadeNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(preferencesRepositoryProvider).loadCrossfade();

  Future<void> set(bool value) async {
    state = value;
    await ref.read(preferencesRepositoryProvider).saveCrossfade(value);
    _apply();
  }

  void _apply() {
    final repository = ref.read(preferencesRepositoryProvider);
    ref.read(playerServiceProvider).configureCrossfade(
          enabled: repository.loadCrossfade(),
          seconds: repository.loadCrossfadeSeconds(),
        );
  }
}

final crossfadeProvider = NotifierProvider<CrossfadeNotifier, bool>(
  CrossfadeNotifier.new,
);

class CrossfadeSecondsNotifier extends Notifier<int> {
  @override
  int build() =>
      ref.watch(preferencesRepositoryProvider).loadCrossfadeSeconds();

  Future<void> set(int seconds) async {
    state = seconds;
    await ref
        .read(preferencesRepositoryProvider)
        .saveCrossfadeSeconds(seconds);
    final repository = ref.read(preferencesRepositoryProvider);
    ref.read(playerServiceProvider).configureCrossfade(
          enabled: repository.loadCrossfade(),
          seconds: repository.loadCrossfadeSeconds(),
        );
  }
}

final crossfadeSecondsProvider =
    NotifierProvider<CrossfadeSecondsNotifier, int>(
      CrossfadeSecondsNotifier.new,
    );

class LastFmEnabledNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(preferencesRepositoryProvider).loadLastFmEnabled() &&
      ref
          .watch(preferencesRepositoryProvider)
          .loadLastFmSessionKey()
          .isNotEmpty;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(preferencesRepositoryProvider).saveLastFmEnabled(value);
  }
}

final lastFmEnabledProvider = NotifierProvider<LastFmEnabledNotifier, bool>(
  LastFmEnabledNotifier.new,
);

class LastFmSessionNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.watch(preferencesRepositoryProvider).loadLastFmSessionKey();

  Future<void> set(String sessionKey) async {
    state = sessionKey;
    await ref
        .read(preferencesRepositoryProvider)
        .saveLastFmSessionKey(sessionKey);
    if (sessionKey.isEmpty) {
      await ref.read(lastFmEnabledProvider.notifier).set(false);
    }
  }
}

final lastFmSessionProvider = NotifierProvider<LastFmSessionNotifier, String>(
  LastFmSessionNotifier.new,
);

class ProfileNameNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(preferencesRepositoryProvider).loadProfileName();

  Future<void> set(String name) async {
    state = name.trim().isEmpty ? 'Music Lover' : name.trim();
    await ref.read(preferencesRepositoryProvider).saveProfileName(state);
  }
}

final profileNameProvider = NotifierProvider<ProfileNameNotifier, String>(
  ProfileNameNotifier.new,
);

// ---------------------------------------------------------------------------
// Listening stats
// ---------------------------------------------------------------------------

class ListeningTimeNotifier extends Notifier<int> {
  @override
  int build() =>
      ref.watch(preferencesRepositoryProvider).loadListeningSeconds();

  Future<void> addMillis(int millis) async {
    if (millis <= 0) return;
    state = state + (millis / 1000).round();
    await ref.read(preferencesRepositoryProvider).saveListeningSeconds(state);
  }
}

final listeningSecondsProvider = NotifierProvider<ListeningTimeNotifier, int>(
  ListeningTimeNotifier.new,
);

/// Profile statistics derived from the library + persisted usage.
class ProfileStats {
  const ProfileStats({
    required this.totalSongs,
    required this.totalArtists,
    required this.totalPlaylists,
    required this.listeningTime,
    required this.favoriteArtistCount,
    required this.topGenres,
  });

  final int totalSongs;
  final int totalArtists;
  final int totalPlaylists;
  final Duration listeningTime;
  final int favoriteArtistCount;
  final List<GenreStat> topGenres;
}

final profileStatsProvider = Provider<ProfileStats>((ref) {
  final library = ref.watch(libraryProvider).value ?? LibraryData.empty;
  final favorites = ref.watch(favoritesProvider);
  final listeningSeconds = ref.watch(listeningSecondsProvider);
  final playlists = ref.watch(playlistsProvider);

  final byId = ref.watch(tracksByIdProvider);
  final favoriteArtists = <int?>{
    for (final id in favorites)
      if (byId[id] != null) byId[id]!.artistId,
  }..remove(null);

  final genres = [...library.genres]
    ..sort((a, b) => b.trackCount.compareTo(a.trackCount));
  final totalGenreTracks = genres.fold<int>(0, (sum, g) => sum + g.trackCount);
  final top = genres.take(3).toList();
  final counted = top.fold<int>(0, (sum, g) => sum + g.trackCount);
  final others = totalGenreTracks - counted;

  final topGenres = <GenreStat>[
    for (final genre in top)
      genre.withShare(
        totalGenreTracks == 0 ? 0 : genre.trackCount / totalGenreTracks,
      ),
    if (others > 0)
      GenreStat(
        name: 'Others',
        trackCount: others,
        share: totalGenreTracks == 0 ? 0 : others / totalGenreTracks,
      ),
  ];

  return ProfileStats(
    totalSongs: library.tracks.length,
    totalArtists: library.artists.length,
    totalPlaylists: playlists.length,
    listeningTime: Duration(seconds: listeningSeconds),
    favoriteArtistCount: favoriteArtists.length,
    topGenres: topGenres,
  );
});

// ---------------------------------------------------------------------------
// Search helpers
// ---------------------------------------------------------------------------

/// Case-insensitive "contains" matcher used across search and filtering.
bool matchesQuery(String? field, String query) {
  if (field == null) return false;
  return field.toLowerCase().contains(query);
}

class SearchResult {
  const SearchResult({
    required this.songs,
    required this.artists,
    required this.albums,
  });

  final List<Track> songs;
  final List<Artist> artists;
  final List<Album> albums;

  bool get isEmpty => songs.isEmpty && artists.isEmpty && albums.isEmpty;
}

SearchResult searchLibrary(LibraryData library, String rawQuery) {
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) {
    return const SearchResult(songs: [], artists: [], albums: []);
  }
  return SearchResult(
    songs: [
      for (final track in library.tracks)
        if (matchesQuery(track.title, query) ||
            matchesQuery(track.artist, query) ||
            matchesQuery(track.album, query))
          track,
    ],
    artists: [
      for (final artist in library.artists)
        if (matchesQuery(artist.name, query)) artist,
    ],
    albums: [
      for (final album in library.albums)
        if (matchesQuery(album.name, query) ||
            matchesQuery(album.artist, query))
          album,
    ],
  );
}

/// Trending selections: derived from actual listening, falling back to
/// library composition when there's no history yet.
class TrendingData {
  const TrendingData({required this.artists, required this.songs});

  final List<Artist> artists;
  final List<Track> songs;
}

TrendingData trendingFromLibrary(
  LibraryData library, {
  required Map<int, int> playCounts,
  required int artistLimit,
  required int songLimit,
}) {
  if (library.isEmpty) {
    return const TrendingData(artists: [], songs: []);
  }

  final playCountTracks =
      library.tracks.where((track) => (playCounts[track.id] ?? 0) > 0).toList()
        ..sort(
          (a, b) => (playCounts[b.id] ?? 0).compareTo(playCounts[a.id] ?? 0),
        );

  final songs = playCountTracks.isNotEmpty
      ? playCountTracks.take(songLimit).toList()
      : library.tracks.take(songLimit).toList();

  final countsByArtistId = <int?, int>{};
  for (final track
      in playCounts.isNotEmpty ? playCountTracks : library.tracks) {
    countsByArtistId[track.artistId] =
        (countsByArtistId[track.artistId] ?? 0) + (playCounts[track.id] ?? 1);
  }
  final artists =
      library.artists.where((a) => countsByArtistId.containsKey(a.id)).toList()
        ..sort(
          (a, b) => (countsByArtistId[b.id] ?? 0).compareTo(
            countsByArtistId[a.id] ?? 0,
          ),
        );
  final fallbackArtists = artists.isEmpty
      ? ([...library.artists]
          ..sort((a, b) => b.trackCount.compareTo(a.trackCount)))
      : artists;

  return TrendingData(
    artists: fallbackArtists.take(artistLimit).toList(),
    songs: songs,
  );
}

final trendingProvider = Provider<TrendingData>((ref) {
  final library = ref.watch(libraryProvider).value ?? LibraryData.empty;
  final playCounts = ref.watch(playCountsProvider);
  return trendingFromLibrary(
    library,
    playCounts: playCounts,
    artistLimit: 6,
    songLimit: 8,
  );
});
