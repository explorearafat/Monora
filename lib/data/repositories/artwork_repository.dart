import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/library_models.dart';
import 'media_repository.dart';

/// Persists MediaStore artwork to the app cache directory so list tiles and
/// media notifications can both use fast `file://` URIs without re-querying
/// MediaStore for every frame.
class ArtworkRepository {
  ArtworkRepository(this._mediaRepository);

  final MediaRepository _mediaRepository;
  final Map<int, String> _memoryCache = {};
  final Map<int, Future<String?>> _inFlight = {};
  Directory? _cacheDir;

  /// Returns a stable cache-file path for the entity's artwork, or null when
  /// the entity has no embedded art. Concurrent lookups for the same id are
  /// de-duplicated.
  Future<String?> artworkPath(int id, ArtworkTarget target) {
    final cached = _memoryCache[id];
    if (cached != null) {
      return Future.value(cached.isEmpty ? null : cached);
    }
    return _inFlight.putIfAbsent(id, () => _loadAndCache(id, target));
  }

  Future<String?> _loadAndCache(int id, ArtworkTarget target) async {
    try {
      final bytes = await _mediaRepository.loadArtwork(id, target);
      if (bytes == null || bytes.isEmpty) {
        _memoryCache[id] = '';
        return null;
      }
      final file = await _writeArtworkFile(id, target, bytes);
      _memoryCache[id] = file.path;
      return file.path;
    } on Exception {
      return null;
    } finally {
      _inFlight.remove(id);
    }
  }

  Future<File> _writeArtworkFile(
    int id,
    ArtworkTarget target,
    Uint8List bytes,
  ) async {
    final cacheDir = _cacheDir ??= await _ensureCacheDir();
    final file = File(
      '${cacheDir.path}${Platform.pathSeparator}art_${target.name}_$id.jpg',
    );
    if (!file.existsSync() || file.lengthSync() != bytes.length) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return file;
  }

  Future<Directory> _ensureCacheDir() async {
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}artwork');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Resolves a `file://` Uri suitable for [MediaItem.artUri], or null.
  Future<Uri?> artworkUri(int id, ArtworkTarget target) async {
    final path = await artworkPath(id, target);
    return path == null || path.isEmpty ? null : Uri.file(path);
  }
}
