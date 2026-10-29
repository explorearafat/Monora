import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Minimal Last.fm scrobbling client (opt-in, keyed).
///
/// Last.fm requires per-application API credentials. Create a free account at
/// https://www.last.fm/api/account/create, then paste the key and shared
/// secret below and rebuild. Without them the feature stays hidden from the
/// UI and nothing is sent anywhere.
abstract final class LastFmConfig {
  static const String apiKey = '';
  static const String apiSecret = '';

  static bool get configured => apiKey.isNotEmpty && apiSecret.isNotEmpty;
}

abstract final class LastFmService {
  static const _root = 'https://ws.audioscrobbler.com/2.0/';

  /// Exchanges a username+password for a scrobble session key
  /// (`auth.getMobileSession`). Returns null when credentials are rejected.
  static Future<String?> authenticate(
    String username,
    String password, {
    http.Client? client,
  }) async {
    if (!LastFmConfig.configured) return null;
    final params = <String, String>{
      'api_key': LastFmConfig.apiKey,
      'method': 'auth.getMobileSession',
      'password': password,
      'username': username,
    };
    params['api_sig'] = _sign(params);
    params['format'] = 'json';
    final response = await _post(params, client);
    try {
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      final session = decoded['session'] as Map<String, Object?>?;
      return session?['key'] as String?;
    } on FormatException {
      return null;
    }
  }

  /// Sends one scrobble. Timestamp must be the moment the track *started*
  /// (unix seconds). Returns true on accepted.
  static Future<bool> scrobble({
    required String sessionKey,
    required String artist,
    required String track,
    String? album,
    required int startedAtSeconds,
    http.Client? client,
  }) async {
    if (!LastFmConfig.configured) return false;
    final params = <String, String>{
      'api_key': LastFmConfig.apiKey,
      'artist': artist,
      if (album != null && album.isNotEmpty) 'album': album,
      'method': 'track.scrobble',
      'sk': sessionKey,
      'timestamp': '$startedAtSeconds',
      'track': track,
    };
    params['api_sig'] = _sign(params);
    params['format'] = 'json';
    final response = await _post(params, client);
    try {
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      return decoded.containsKey('scrobbles');
    } on FormatException {
      return false;
    }
  }

  /// Last.fm signature: params sorted by name, concatenated name+value,
  /// secret appended, MD5-hexed.
  static String _sign(Map<String, String> params) {
    final buffer = StringBuffer();
    final names = params.keys.where((n) => n != 'format').toList()..sort();
    for (final name in names) {
      buffer
        ..write(name)
        ..write(params[name]);
    }
    buffer.write(LastFmConfig.apiSecret);
    return md5.convert(utf8.encode(buffer.toString())).toString();
  }

  static Future<http.Response> _post(
    Map<String, String> params,
    http.Client? client,
  ) async {
    final effective = client ?? http.Client();
    final request = http.Request('POST', Uri.parse(_root))..bodyFields = params;
    try {
      final response = await effective.send(request);
      return await http.Response.fromStream(response);
    } finally {
      if (client == null) effective.close();
    }
  }
}
