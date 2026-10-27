import 'package:flutter_test/flutter_test.dart';
import 'package:monora/data/models/library_models.dart';
import 'package:monora/data/repositories/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PreferencesRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    repository = PreferencesRepository(prefs);
  });

  test('favorites round-trip', () async {
    expect(repository.loadFavoriteIds(), isEmpty);
    await repository.saveFavoriteIds({3, 17, 42});
    expect(repository.loadFavoriteIds(), {3, 17, 42});
  });

  test('recents preserve order (most recent first)', () async {
    await repository.saveRecentTrackIds([9, 4, 7]);
    expect(repository.loadRecentTrackIds(), [9, 4, 7]);
  });

  test('play counts round-trip through JSON', () async {
    await repository.savePlayCounts({1: 3, 8: 12});
    expect(repository.loadPlayCounts(), {1: 3, 8: 12});
  });

  test('playlists round-trip', () async {
    final playlist = MonoraPlaylist(
      id: 'abc',
      name: 'Chill Vibes',
      trackIds: [1, 2, 3],
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
    await repository.savePlaylists([playlist]);
    final loaded = repository.loadPlaylists();
    expect(loaded, hasLength(1));
    expect(loaded.first.name, 'Chill Vibes');
    expect(loaded.first.trackIds, [1, 2, 3]);
  });

  test('settings default to sensible values', () {
    expect(repository.loadThemeMode(), 'system');
    expect(repository.loadAccentName(), 'Orange');
    expect(repository.loadPauseOnInterruptions(), isTrue);
    expect(repository.loadResumeSession(), isTrue);
    expect(repository.loadPlaybackSpeed(), 1.0);
    expect(repository.loadListeningSeconds(), 0);
    expect(repository.loadProfileName(), 'Music Lover');
  });

  test('last session snapshot round-trip and clearing', () async {
    final snapshot = LastSessionSnapshot(
      trackIds: [5, 6, 7],
      trackIndex: 2,
      positionMs: 91000,
      shuffle: true,
      loopModeIndex: 1,
    );
    await repository.saveLastSession(snapshot);
    expect(repository.loadLastSession()?.trackIndex, 2);
    expect(repository.loadLastSession()?.positionMs, 91000);
    expect(repository.loadLastSession()?.shuffle, isTrue);

    await repository.saveLastSession(null);
    expect(repository.loadLastSession(), isNull);
  });
}
