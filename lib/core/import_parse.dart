import 'dart:convert';

/// Satu lagu dari sumber luar. [artist] kosong = baris teks bebas (mis. "Artis - Judul"), dicari apa adanya.
class ImportedTrack {
  final String title;
  final String artist;
  const ImportedTrack(this.title, [this.artist = '']);
}

class ImportedList {
  final String name;
  final List<ImportedTrack> tracks;
  const ImportedList(this.name, this.tracks);
}

/// Kandidat hasil pencarian (dipisah dari tipe lain supaya bagian ini bisa diuji sendiri).
class Cand {
  final String title;
  final String artists;
  final Object? ref;
  const Cand(this.title, this.artists, [this.ref]);
}

enum LinkKind { spotify, deezer, youtube, unknown }

/// Pembaca format: CSV (Exportify, TuneMyMusic, Soundiiz, dll.), JSON (termasuk ekspor data Spotify),
/// M3U, teks biasa, serta halaman embed Spotify. Dart murni.
class ImportParsers {
  ImportParsers._();

  // ------------------------------------------------------------------------------------------ link
  static LinkKind kindOf(String url) {
    final u = url.toLowerCase();
    if (u.contains('spotify')) return LinkKind.spotify;
    if (u.contains('deezer')) return LinkKind.deezer;
    if (u.contains('youtube.com') || u.contains('youtu.be') || u.contains('music.youtube')) return LinkKind.youtube;
    return LinkKind.unknown;
  }

  /// (jenis, id): jenis = playlist | album. Mendukung link web dan "spotify:playlist:ID".
  static (String, String)? spotifyRef(String url) {
    final m = RegExp(r'(playlist|album)[/:]([A-Za-z0-9]{10,})').firstMatch(url);
    return m == null ? null : (m.group(1)!, m.group(2)!);
  }

  static String? deezerPlaylistId(String url) => RegExp(r'playlist/(\d+)').firstMatch(url)?.group(1);

  static String? youtubeListId(String url) => RegExp(r'[?&]list=([A-Za-z0-9_-]+)').firstMatch(url)?.group(1);

  // ------------------------------------------------------------------------------------------ Spotify embed
  /// Membaca halaman embed Spotify (open.spotify.com/embed/...). Tanpa login, maksimal sekitar 100 lagu.
  static ImportedList? spotifyEmbed(String html) {
    final json = RegExp(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true).firstMatch(html)?.group(1);
    if (json != null) {
      try {
        final entity = _findMapWith(jsonDecode(json), 'trackList');
        final arr = entity?['trackList'];
        if (entity != null && arr is List) {
          final tracks = <ImportedTrack>[];
          for (final o in arr) {
            if (o is! Map) continue;
            final t = (o['title'] as String? ?? '').trim();
            if (t.isNotEmpty) tracks.add(ImportedTrack(t, _cleanArtist(o['subtitle'] as String? ?? '')));
          }
          if (tracks.isNotEmpty) {
            final name = _firstNonBlank([entity['name'], entity['title']]) ?? 'Playlist Spotify';
            return ImportedList(name, tracks);
          }
        }
      } catch (_) {/* lanjut ke cadangan */}
    }
    // Cadangan kalau struktur halaman berubah: ambil pasangan "title"/"subtitle" langsung dari teks.
    final pairs = <ImportedTrack>[];
    final seen = <String>{};
    for (final m in RegExp(r'"title":"((?:[^"\\]|\\.)*)","subtitle":"((?:[^"\\]|\\.)*)"').allMatches(html)) {
      final t = _unescape(m.group(1)!);
      final a = _cleanArtist(_unescape(m.group(2)!));
      if (t.isNotEmpty && seen.add('$t|$a')) pairs.add(ImportedTrack(t, a));
    }
    if (pairs.isEmpty) return null;
    final title = RegExp(r'<title>(.*?)</title>', dotAll: true).firstMatch(html)?.group(1) ?? '';
    final name = title.split(' | ').first.split(' - ').first.trim();
    return ImportedList(name.isEmpty ? 'Playlist Spotify' : name, pairs);
  }

  static String? _firstNonBlank(List<dynamic> v) {
    for (final x in v) {
      if (x is String && x.trim().isNotEmpty) return x;
    }
    return null;
  }

  static String _cleanArtist(String s) => s.replaceAll('\u00A0', ' ').trim();

  static String _unescape(String s) {
    try {
      return jsonDecode('"$s"') as String;
    } catch (_) {
      return s;
    }
  }

  static Map? _findMapWith(dynamic node, String key) {
    if (node is Map) {
      if (node.containsKey(key)) return node;
      for (final v in node.values) {
        final r = _findMapWith(v, key);
        if (r != null) return r;
      }
    } else if (node is List) {
      for (final v in node) {
        final r = _findMapWith(v, key);
        if (r != null) return r;
      }
    }
    return null;
  }

  // ------------------------------------------------------------------------------------------ teks / file
  /// Satu file bisa berisi banyak playlist (mis. ekspor data Spotify). Daftar kosong kalau tidak terbaca.
  static List<ImportedList> parseText(String defaultName, String raw) {
    var text = raw;
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    text = text.trim();
    if (text.isEmpty) return [];
    List<ImportedList> out;
    if (text.startsWith('[') || text.startsWith('{')) {
      try {
        out = _parseJson(defaultName, text);
      } catch (_) {
        out = [];
      }
    } else if (text.startsWith('#EXTM3U') || text.contains('#EXTINF')) {
      out = [_parseM3u(defaultName, text)];
    } else if (_looksLikeCsv(text)) {
      out = [_parseCsv(defaultName, text)];
    } else {
      out = [_parseLines(defaultName, text)];
    }
    return out.where((l) => l.tracks.isNotEmpty).toList();
  }

  static bool _looksLikeCsv(String text) {
    final first = text.split('\n').first;
    return first.contains(',') || first.contains(';') || first.contains('\t');
  }

  // --- baris bebas
  static ImportedList _parseLines(String name, String text) {
    final tracks = <ImportedTrack>[];
    for (final l in text.split('\n')) {
      var s = l.trim();
      if (s.isEmpty || s.startsWith('#') || s.startsWith('//')) continue;
      s = s.replaceFirst(RegExp(r'^\d+[.)]\s+'), '').trim();
      if (s.isNotEmpty) tracks.add(ImportedTrack(s));
    }
    return ImportedList(name, tracks);
  }

  // --- M3U
  static ImportedList _parseM3u(String name, String text) {
    final tracks = <ImportedTrack>[];
    for (final l in text.split('\n')) {
      final s = l.trim();
      if (s.startsWith('#EXTINF:')) {
        final i = s.indexOf(',');
        final title = i < 0 ? '' : s.substring(i + 1).trim();
        if (title.isNotEmpty) tracks.add(ImportedTrack(title));
      }
    }
    return ImportedList(name, tracks);
  }

  // --- CSV
  static const _titleKeys = ['trackname', 'tracktitle', 'songname', 'songtitle', 'title', 'song', 'track', 'name'];
  static const _artistKeys = ['artistnames', 'artistname', 'artists', 'artist', 'performer', 'creator'];

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

  static List<List<String>> _splitCsv(String text) {
    final head = text.split('\n').first;
    int count(String d) => d.allMatches(head).length;
    var delim = ',';
    var best = count(',');
    for (final d in [';', '\t']) {
      if (count(d) > best) {
        best = count(d);
        delim = d;
      }
    }
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var q = false;
    void endCell() {
      row.add(cell.toString());
      cell.clear();
    }

    void endRow() {
      endCell();
      if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    }

    var i = 0;
    while (i < text.length) {
      final c = text[i];
      if (q && c == '"' && i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else if (c == '"') {
        q = !q;
      } else if (!q && c == delim) {
        endCell();
      } else if (!q && (c == '\n' || c == '\r')) {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      } else {
        cell.write(c);
      }
      i++;
    }
    if (cell.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  static ImportedList _parseCsv(String name, String text) {
    final rows = _splitCsv(text);
    if (rows.isEmpty) return ImportedList(name, const []);
    final header = rows.first.map(_norm).toList();
    int? find(List<String> keys) {
      for (final k in keys) {
        final i = header.indexOf(k);
        if (i >= 0) return i;
      }
      return null;
    }

    final ti = find(_titleKeys);
    final ai = find(_artistKeys);
    final List<List<String>> data;
    final int tCol;
    final int? aCol;
    if (ti != null) {
      data = rows.sublist(1);
      tCol = ti;
      aCol = ai;
    } else {
      data = rows;
      tCol = 0;
      aCol = rows.first.length >= 2 ? 1 : null;
    }
    final tracks = <ImportedTrack>[];
    for (final r in data) {
      final t = (tCol < r.length ? r[tCol] : '').trim();
      if (t.isEmpty) continue;
      final a = aCol != null && aCol < r.length ? r[aCol].replaceAll(';', ' ').trim() : '';
      tracks.add(ImportedTrack(t, a));
    }
    return ImportedList(name, tracks);
  }

  // --- JSON
  static const _jTitle = ['trackName', 'track_name', 'title', 'name', 'track', 'song', 'songName'];
  static const _jArtist = ['artistName', 'artist_name', 'artist', 'artists', 'creator', 'author'];
  static const _jLists = ['items', 'tracks', 'songs', 'data'];

  static List? _firstList(Map m) {
    for (final k in _jLists) {
      final v = m[k];
      if (v is List) return v;
    }
    return null;
  }

  static List<ImportedList> _parseJson(String defaultName, String text) {
    final root = jsonDecode(text);
    if (root is List) return [ImportedList(defaultName, _tracksOf(root))];
    if (root is! Map) return [];
    final pls = root['playlists'];
    if (pls is List) {
      final out = <ImportedList>[];
      for (var i = 0; i < pls.length; i++) {
        final p = pls[i];
        if (p is! Map) continue;
        final arr = _firstList(p);
        if (arr == null) continue;
        final n = (p['name'] as String?)?.trim() ?? '';
        out.add(ImportedList(n.isEmpty ? '$defaultName ${i + 1}' : n, _tracksOf(arr)));
      }
      return out;
    }
    final arr = _firstList(root);
    if (arr == null) return [];
    return [ImportedList(_firstNonBlank([root['name'], root['title']]) ?? defaultName, _tracksOf(arr))];
  }

  static List<ImportedTrack> _tracksOf(List arr) {
    final out = <ImportedTrack>[];
    for (final e in arr) {
      if (e is String) {
        if (e.trim().isNotEmpty) out.add(ImportedTrack(e.trim()));
      } else if (e is Map) {
        final t = _trackOf(e);
        if (t != null) out.add(t);
      }
    }
    return out;
  }

  static ImportedTrack? _trackOf(Map o0) {
    var o = o0;
    // Ekspor Spotify membungkus lagu di dalam "track": {...}
    if (o['track'] is Map) o = o['track'] as Map;
    String? title;
    for (final k in _jTitle) {
      final v = o[k];
      if (v is String && v.trim().isNotEmpty) {
        title = v;
        break;
      }
    }
    if (title == null) return null;
    var artist = '';
    for (final k in _jArtist) {
      final v = o[k];
      String? a;
      if (v is String && v.trim().isNotEmpty) {
        a = v;
      } else if (v is List) {
        final names = v.map((x) => x is String ? x : (x is Map ? (x['name'] as String? ?? '') : '')).where((s) => s.trim().isNotEmpty);
        if (names.isNotEmpty) a = names.join(' ');
      } else if (v is Map && (v['name'] as String?)?.trim().isNotEmpty == true) {
        a = v['name'] as String;
      }
      if (a != null) {
        artist = a;
        break;
      }
    }
    return ImportedTrack(title.trim(), artist.trim());
  }

  // ------------------------------------------------------------------------------------------ pencocokan
  static const _variantWords = ['live', 'remix', 'karaoke', 'instrumental', 'sped up', 'slowed', 'cover', 'tribute', '8d', 'nightcore'];
  static const _noise = {'feat', 'ft', 'featuring', 'remastered', 'remaster', 'version', 'official', 'video', 'audio', 'lyrics', 'explicit', 'original', 'radio', 'edit'};

  static Set<String> tokens(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), ' ')
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ');
    return cleaned.split(' ').where((t) => t.isNotEmpty && !_noise.contains(t)).toSet();
  }

  /// Pilih kandidat terbaik untuk [want], atau null kalau tidak ada yang cukup mirip.
  static Cand? pick(List<Cand> cands, ImportedTrack want) {
    if (cands.isEmpty) return null;
    final w = tokens(want.title);
    if (w.isEmpty) return null;
    final top = cands.take(5).toList();
    if (want.artist.trim().isEmpty) {
      // Baris bebas: judul kandidat harus "terkandung" di baris yang dicari.
      Cand? best;
      var bestScore = 0.5 - 1e-9;
      for (final c in top) {
        final ct = tokens(c.title);
        if (ct.isEmpty) continue;
        final s = ct.where(w.contains).length / ct.length;
        if (s >= 0.5 && s > bestScore) {
          best = c;
          bestScore = s;
        }
      }
      return best;
    }
    final wa = tokens(want.artist);
    Cand? best;
    var bestScore = -1e9;
    for (final c in top) {
      final ct = tokens(c.title);
      final t = w.where(ct.contains).length / w.length;
      final ca = tokens(c.artists);
      final a = wa.isEmpty ? 1.0 : wa.where(ca.contains).length / wa.length;
      if (t >= 0.5 && (a > 0 || t >= 1)) {
        var score = t * 2 + a;
        if (c.title.trim().toLowerCase() == want.title.trim().toLowerCase()) score += 0.5;
        final lc = c.title.toLowerCase();
        final lw = want.title.toLowerCase();
        if (_variantWords.any((v) => lc.contains(v) && !lw.contains(v))) score -= 1;
        if (score > bestScore) {
          best = c;
          bestScore = score;
        }
      }
    }
    return best;
  }
}
