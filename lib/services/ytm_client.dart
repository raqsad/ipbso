import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models.dart';
import '../core/ytm_parse.dart';

/// Klien YouTube Music (InnerTube) minimal: cari lagu, Home, Charts, dan lagu terkait.
class YtmClient {
  static const _base = 'https://music.youtube.com/youtubei/v1';
  static const _ua =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
  static const _songsFilter = 'EgWKAQIIAWoMEA4QChADEAQQCRAF';

  final http.Client _c = http.Client();

  Future<dynamic> _post(String endpoint, Map<String, dynamic> body, {String extraQuery = ''}) async {
    final res = await _c
        .post(
          Uri.parse('$_base/$endpoint?alt=json&prettyPrint=false$extraQuery'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': _ua,
            'Origin': 'https://music.youtube.com',
            'Referer': 'https://music.youtube.com/',
          },
          body: jsonEncode({
            'context': {
              'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.20241127.01.00', 'hl': 'id', 'gl': 'ID'},
            },
            ...body,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<List<Track>> searchSongs(String query) async {
    var tracks = parseTracks(await _post('search', {'query': query, 'params': _songsFilter}));
    if (tracks.isEmpty) tracks = parseTracks(await _post('search', {'query': query}));
    return tracks;
  }

  /// Halaman Home + lanjutannya (sampai [pages] halaman).
  Future<List<Shelf>> home({int pages = 4}) async {
    final shelves = <Shelf>[];
    dynamic r = await _post('browse', {'browseId': 'FEmusic_home'});
    shelves.addAll(parseShelves(r));
    for (var i = 1; i < pages; i++) {
      final token = _continuation(r);
      if (token == null) break;
      try {
        r = await _post('browse', {}, extraQuery: '&ctoken=$token&continuation=$token');
      } catch (_) {
        break;
      }
      shelves.addAll(parseShelves(r));
    }
    return shelves;
  }

  Future<List<Shelf>> charts() async => parseShelves(await _post('browse', {'browseId': 'FEmusic_charts'}));

  /// Lagu mirip (radio) dari [videoId], tanpa lagu itu sendiri.
  Future<List<Track>> related(String videoId) async {
    final r = await _post('next', {'videoId': videoId, 'playlistId': 'RDAMVM$videoId', 'isAudioOnly': true});
    return parseTracks(r).where((t) => t.id != videoId).toList();
  }

  String? _continuation(dynamic node) {
    if (node is Map) {
      final n = node['nextContinuationData'];
      if (n is Map && n['continuation'] is String) return n['continuation'] as String;
      for (final v in node.values) {
        final r = _continuation(v);
        if (r != null) return r;
      }
    } else if (node is List) {
      for (final v in node) {
        final r = _continuation(v);
        if (r != null) return r;
      }
    }
    return null;
  }
}
