import 'dart:io';

/// Which entity an artwork lookup refers to.
enum ArtworkTarget { track, album, artist }

/// A playable track from the device media library.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.artistId,
    required this.album,
    required this.albumId,
    required this.duration,
    required this.file,
    required this.uri,
    required this.fileExtension,
    this.genre,
    this.size = 0,
    this.dateAdded = 0,
  });

  final int id;
  final String title;

  /// Artist display name; `'Unknown Artist'` when the tag is missing.
  final String artist;
  final int? artistId;

  /// Album display name; `'Unknown Album'` when the tag is missing.
  final String album;
  final int? albumId;
  final Duration duration;

  /// Absolute path of the audio file on disk.
  final String file;
  final Uri uri;
  final String fileExtension;
  final String? genre;
  final int size;
  final int dateAdded;

  /// File name without extension, e.g. `song` for `/music/song.mp3`; used to
  /// locate sibling `.lrc` lyrics files.
  String get lyricsBaseName {
    final name = file.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  Track copyWith({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
  }) {
    return Track(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artistId: artistId,
      album: album ?? this.album,
      albumId: albumId,
      duration: duration ?? this.duration,
      file: file,
      uri: uri,
      fileExtension: fileExtension,
      genre: genre,
      size: size,
      dateAdded: dateAdded,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'artistId': artistId,
    'album': album,
    'albumId': albumId,
    'duration': duration.inMilliseconds,
    'file': file,
    'uri': uri.toString(),
    'fileExtension': fileExtension,
    'genre': genre,
    'size': size,
    'dateAdded': dateAdded,
  };

  /// Restores a track snapshot (used to resume the last session after the
  /// library is re-scanned; returns null when the file disappeared).
  static Track? fromJson(Map<String, Object?> json) {
    final file = json['file'] as String?;
    if (file == null || !File(file).existsSync()) return null;
    final millis = (json['duration'] as num?)?.toInt() ?? 0;
    return Track(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? 'Unknown Title',
      artist: (json['artist'] as String?) ?? 'Unknown Artist',
      artistId: (json['artistId'] as num?)?.toInt(),
      album: (json['album'] as String?) ?? 'Unknown Album',
      albumId: (json['albumId'] as num?)?.toInt(),
      duration: Duration(milliseconds: millis),
      file: file,
      uri: Uri.parse((json['uri'] as String?) ?? Uri.file(file).toString()),
      fileExtension: (json['fileExtension'] as String?) ?? '',
      genre: json['genre'] as String?,
      size: (json['size'] as num?)?.toInt() ?? 0,
      dateAdded: (json['dateAdded'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// An album grouping.
class Album {
  const Album({
    required this.id,
    required this.name,
    required this.artist,
    required this.artistId,
    required this.trackCount,
  });

  final int id;
  final String name;
  final String artist;
  final int? artistId;
  final int trackCount;

  @override
  bool operator ==(Object other) => other is Album && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// An artist grouping.
class Artist {
  const Artist({
    required this.id,
    required this.name,
    required this.albumCount,
    required this.trackCount,
  });

  final int id;
  final String name;
  final int albumCount;
  final int trackCount;

  @override
  bool operator ==(Object other) => other is Artist && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A user-created playlist stored locally in the app.
class MonoraPlaylist {
  const MonoraPlaylist({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<int> trackIds;
  final DateTime createdAt;

  MonoraPlaylist copyWith({String? name, List<int>? trackIds}) {
    return MonoraPlaylist(
      id: id,
      name: name ?? this.name,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'trackIds': trackIds,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  static MonoraPlaylist fromJson(Map<String, Object?> json) {
    return MonoraPlaylist(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Playlist',
      trackIds: ((json['trackIds'] as List<Object?>?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(growable: false),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  @override
  bool operator ==(Object other) => other is MonoraPlaylist && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One slice of the "Top Genres" distribution shown on the profile screen.
class GenreStat {
  const GenreStat({required this.name, required this.trackCount, this.share});

  final String name;
  final int trackCount;

  /// Fraction of the library belonging to this genre (0..1), computed by the
  /// profile screen once the total is known.
  final double? share;

  GenreStat withShare(double share) =>
      GenreStat(name: name, trackCount: trackCount, share: share);
}
