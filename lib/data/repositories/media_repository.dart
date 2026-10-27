import 'dart:typed_data';

import 'package:on_audio_query/on_audio_query.dart';

import '../../data/models/library_models.dart';

/// Read-only view over the device media library. Abstracted so widget tests
/// can substitute an in-memory implementation.
abstract class MediaRepository {
  /// All music tracks on the device, newest first by default.
  Future<List<Track>> loadTracks();

  Future<List<Album>> loadAlbums();

  Future<List<Artist>> loadArtists();

  /// Genre distribution of the library, sorted by track count.
  Future<List<GenreStat>> loadGenreStats();

  /// Artwork bytes for a track/album/artist id, or null when none exists.
  Future<Uint8List?> loadArtwork(int id, ArtworkTarget target);
}

/// Production implementation backed by the `on_audio_query` MediaStore
/// integration.
class OnAudioQueryMediaRepository implements MediaRepository {
  OnAudioQueryMediaRepository({OnAudioQuery? query})
    : _query = query ?? OnAudioQuery();

  final OnAudioQuery _query;

  static const Set<String> _audioExtensions = {
    'mp3',
    'm4a',
    'aac',
    'flac',
    'wav',
    'ogg',
    'opus',
    'wma',
    'aiff',
    'alac',
  };

  @override
  Future<List<Track>> loadTracks() async {
    final songs = await _query.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
      uriType: UriType.EXTERNAL,
    );
    final tracks = <Track>[];
    for (final song in songs) {
      final extension = song.fileExtension.toLowerCase();
      // MediaStore can surface ringtones/notifications; keep real music only.
      if (song.isMusic == false) continue;
      if (_audioExtensions.contains(extension)) {
        tracks.add(_toTrack(song));
      }
    }
    return tracks;
  }

  Track _toTrack(SongModel song) {
    final path = song.data;
    return Track(
      id: song.id,
      title: song.title.trim().isEmpty
          ? song.displayNameWOExt
          : song.title.trim(),
      artist: _cleanTag(song.artist) ?? 'Unknown Artist',
      artistId: song.artistId,
      album: _cleanTag(song.album) ?? 'Unknown Album',
      albumId: song.albumId,
      duration: Duration(milliseconds: song.duration ?? 0),
      file: path,
      uri: Uri.parse(song.uri ?? Uri.file(path).toString()),
      fileExtension: song.fileExtension,
      genre: _cleanTag(song.genre),
      size: song.size,
      dateAdded: song.dateAdded ?? 0,
    );
  }

  /// MediaStore tags use `<unknown>` sentinels; normalize them to null.
  String? _cleanTag(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == '<unknown>') return null;
    return trimmed;
  }

  @override
  Future<List<Album>> loadAlbums() async {
    final albums = await _query.queryAlbums(
      sortType: AlbumSortType.ALBUM,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
    return [
      for (final album in albums)
        Album(
          id: album.id,
          name: _cleanTag(album.album) ?? 'Unknown Album',
          artist: _cleanTag(album.artist) ?? 'Unknown Artist',
          artistId: album.artistId,
          trackCount: album.numOfSongs,
        ),
    ];
  }

  @override
  Future<List<Artist>> loadArtists() async {
    final artists = await _query.queryArtists(
      sortType: ArtistSortType.ARTIST,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
    return [
      for (final artist in artists)
        if (_cleanTag(artist.artist) != null)
          Artist(
            id: artist.id,
            name: _cleanTag(artist.artist)!,
            albumCount: artist.numberOfAlbums ?? 0,
            trackCount: artist.numberOfTracks ?? 0,
          ),
    ];
  }

  @override
  Future<List<GenreStat>> loadGenreStats() async {
    final genres = await _query.queryGenres(uriType: UriType.EXTERNAL);
    final stats = [
      for (final genre in genres)
        if (_cleanTag(genre.genre) != null && genre.numOfSongs > 0)
          GenreStat(
            name: _cleanTag(genre.genre)!,
            trackCount: genre.numOfSongs,
          ),
    ];
    stats.sort((a, b) => b.trackCount.compareTo(a.trackCount));
    return stats;
  }

  @override
  Future<Uint8List?> loadArtwork(int id, ArtworkTarget target) async {
    final type = switch (target) {
      ArtworkTarget.track => ArtworkType.AUDIO,
      ArtworkTarget.album => ArtworkType.ALBUM,
      ArtworkTarget.artist => ArtworkType.ARTIST,
    };
    try {
      return await _query.queryArtwork(
        id,
        type,
        format: ArtworkFormat.JPEG,
        size: 300,
        quality: 85,
      );
    } on Exception {
      return null;
    }
  }
}

/// In-memory implementation for tests and (potentially) desktop previews.
class InMemoryMediaRepository implements MediaRepository {
  InMemoryMediaRepository({
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
    this.genres = const [],
    this.artwork,
  });

  final List<Track> tracks;
  final List<Album> albums;
  final List<Artist> artists;
  final List<GenreStat> genres;
  final Uint8List? artwork;

  @override
  Future<List<Track>> loadTracks() async => tracks;

  @override
  Future<List<Album>> loadAlbums() async => albums;

  @override
  Future<List<Artist>> loadArtists() async => artists;

  @override
  Future<List<GenreStat>> loadGenreStats() async => genres;

  @override
  Future<Uint8List?> loadArtwork(int id, ArtworkTarget target) async => artwork;
}
