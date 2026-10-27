import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/utils/lrc_parser.dart';
import '../models/library_models.dart';

/// Finds offline `.lrc` lyrics for a track.
///
/// Lookup order (first hit wins):
///  1. a sibling `<track-name>.lrc` next to the audio file,
///  2. `<app documents>/lyrics/<track-name>.lrc`,
///  3. `<app documents>/lyrics/<artist> - <track-name>.lrc`.
///
/// Monora never invents lyrics: when no file is found the caller renders an
/// empty state instead of fabricated content.
class LyricsRepository {
  Directory? _lyricsDir;

  Future<LrcContent?> findLyrics(Track track) async {
    final candidates = <String>[
      '${_dirOf(track.file)}${Platform.pathSeparator}${track.lyricsBaseName}.lrc',
      '${(await _ensureLyricsDir()).path}${Platform.pathSeparator}${track.lyricsBaseName}.lrc',
      '${(await _ensureLyricsDir()).path}${Platform.pathSeparator}${_sanitize(track.artist)} - ${track.lyricsBaseName}.lrc',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          final content = LrcParser.parse(file.readAsStringSync());
          if (content != null && content.hasText) {
            return content;
          }
        } on FileSystemException {
          continue;
        }
      }
    }
    return null;
  }

  String _dirOf(String path) {
    final separatorIndex = path.lastIndexOf(Platform.pathSeparator);
    return separatorIndex <= 0 ? '' : path.substring(0, separatorIndex);
  }

  String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();

  Future<Directory> _ensureLyricsDir() async {
    final existing = _lyricsDir;
    if (existing != null) return existing;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}lyrics');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return _lyricsDir = dir;
  }
}
