import 'package:flutter_test/flutter_test.dart';
import 'package:monora/data/models/library_models.dart';
import 'package:monora/providers/app_providers.dart';

LibraryData _library() {
  Track track(
    int id,
    String title,
    String artist,
    String album, {
    int? artistId = 1,
    int? albumId = 1,
  }) {
    return Track(
      id: id,
      title: title,
      artist: artist,
      artistId: artistId,
      album: album,
      albumId: albumId,
      duration: Duration(minutes: 3 + id),
      file: '/music/$id.mp3',
      uri: Uri.file('/music/$id.mp3'),
      fileExtension: 'mp3',
    );
  }

  return LibraryData(
    tracks: [
      track(1, 'Blinding Lights', 'The Weeknd', 'After Hours'),
      track(
        2,
        'Anti-Hero',
        'Taylor Swift',
        'Midnights',
        artistId: 2,
        albumId: 2,
      ),
      track(3, 'Save Your Tears', 'The Weeknd', 'After Hours'),
      track(
        4,
        'Space Song',
        'Beach House',
        'Depression Cherry',
        artistId: 3,
        albumId: 3,
      ),
    ],
    albums: const [
      Album(
        id: 1,
        name: 'After Hours',
        artist: 'The Weeknd',
        artistId: 1,
        trackCount: 2,
      ),
      Album(
        id: 2,
        name: 'Midnights',
        artist: 'Taylor Swift',
        artistId: 2,
        trackCount: 1,
      ),
    ],
    artists: const [
      Artist(id: 1, name: 'The Weeknd', albumCount: 1, trackCount: 2),
      Artist(id: 2, name: 'Taylor Swift', albumCount: 1, trackCount: 1),
      Artist(id: 3, name: 'Beach House', albumCount: 1, trackCount: 1),
    ],
    genres: const [
      GenreStat(name: 'Hip-Hop', trackCount: 32),
      GenreStat(name: 'Lo-fi', trackCount: 24),
      GenreStat(name: 'Rock', trackCount: 18),
      GenreStat(name: 'Jazz', trackCount: 6),
    ],
    scannedAt: DateTime(2026),
  );
}

void main() {
  group('searchLibrary', () {
    final library = _library();

    test('matches song titles case-insensitively', () {
      final result = searchLibrary(library, 'blinding');
      expect(result.songs, hasLength(1));
      expect(result.songs.first.title, 'Blinding Lights');
    });

    test('matches artists via song search', () {
      final result = searchLibrary(library, 'weeknd');
      expect(result.songs, hasLength(2));
      expect(result.artists.map((a) => a.name), contains('The Weeknd'));
    });

    test('matches album names', () {
      final result = searchLibrary(library, 'midnights');
      expect(result.albums, hasLength(1));
      expect(result.albums.first.name, 'Midnights');
    });

    test('empty query yields empty result', () {
      expect(searchLibrary(library, '   ').isEmpty, isTrue);
    });

    test('no matches yield empty result', () {
      expect(searchLibrary(library, 'zzzz').isEmpty, isTrue);
    });
  });

  group('trendingFromLibrary', () {
    test('uses play counts when history exists', () {
      final trending = trendingFromLibrary(
        _library(),
        playCounts: {4: 9, 1: 5, 2: 2},
        artistLimit: 2,
        songLimit: 3,
      );
      expect(trending.songs.first.id, 4);
      expect(trending.songs, hasLength(3));
      // Beach House has the most plays -> first trending artist.
      expect(trending.artists.first.name, 'Beach House');
    });

    test('falls back to library composition without history', () {
      final trending = trendingFromLibrary(
        _library(),
        playCounts: {},
        artistLimit: 2,
        songLimit: 4,
      );
      // The Weeknd has the most tracks.
      expect(trending.artists.first.name, 'The Weeknd');
      expect(trending.songs, hasLength(4));
    });
  });
}
