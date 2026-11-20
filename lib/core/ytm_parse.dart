import 'models.dart';

/// Pembaca respons YouTube Music (InnerTube). Dibuat longgar: menelusuri JSON secara rekursif,
/// jadi tetap jalan walau struktur halamannya sedikit berubah.

String? _runsText(dynamic node) {
  if (node is Map) {
    final runs = node['runs'];
    if (runs is List && runs.isNotEmpty && runs.first is Map) return (runs.first as Map)['text'] as String?;
    if (node['simpleText'] is String) return node['simpleText'] as String;
  }
  return null;
}

String? _findString(dynamic node, String key) {
  if (node is Map) {
    final v = node[key];
    if (v is String) return v;
    for (final c in node.values) {
      final r = _findString(c, key);
      if (r != null) return r;
    }
  } else if (node is List) {
    for (final c in node) {
      final r = _findString(c, key);
      if (r != null) return r;
    }
  }
  return null;
}

/// Gambar terakhir (terbesar) dari daftar thumbnails di dalam [node], dibesarkan ke 544px kalau dari googleusercontent.
String? _cover(dynamic node) {
  List? find(dynamic n) {
    if (n is Map) {
      final t = n['thumbnails'];
      if (t is List && t.isNotEmpty) return t;
      for (final c in n.values) {
        final r = find(c);
        if (r != null) return r;
      }
    } else if (n is List) {
      for (final c in n) {
        final r = find(c);
        if (r != null) return r;
      }
    }
    return null;
  }

  final list = find(node);
  if (list == null) return null;
  final url = (list.last as Map)['url'] as String?;
  if (url == null) return null;
  return url.contains('googleusercontent.com') || url.contains('ggpht.com')
      ? url.replaceAll(RegExp(r'=w\d+-h\d+.*$'), '=w544-h544')
      : url;
}

/// Pecah deretan "runs" jadi kelompok yang dipisah " • ".
List<String> _groups(List runs) {
  final out = <String>[];
  var cur = StringBuffer();
  for (final r in runs) {
    final t = (r is Map ? r['text'] : null) as String? ?? '';
    if (t.trim() == '•' || t.trim() == '·') {
      if (cur.isNotEmpty) out.add(cur.toString().trim());
      cur = StringBuffer();
    } else {
      cur.write(t);
    }
  }
  if (cur.isNotEmpty) out.add(cur.toString().trim());
  return out.where((s) => s.isNotEmpty).toList();
}

final _typeWords = {'song', 'lagu', 'video', 'single', 'episode', 'ep', 'album', 'musik video', 'music video'};
final _durRe = RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$');

int? _parseDur(String s) {
  if (!_durRe.hasMatch(s)) return null;
  final p = s.split(':').map(int.parse).toList();
  return p.length == 3 ? p[0] * 3600 + p[1] * 60 + p[2] : p[0] * 60 + p[1];
}

/// groups -> (artist, durasi) dengan membuang label jenis ("Song"/"Lagu") dan durasi.
({String artist, int? dur}) _artistAndDur(List<String> groups) {
  int? dur;
  final rest = <String>[];
  for (final g in groups) {
    final d = _parseDur(g);
    if (d != null) {
      dur = d;
    } else if (!_typeWords.contains(g.toLowerCase())) {
      rest.add(g);
    }
  }
  return (artist: rest.isEmpty ? '' : rest.first, dur: dur);
}

Track? _fromResponsive(Map r) {
  final id = r['playlistItemData'] is Map ? (r['playlistItemData'] as Map)['videoId'] as String? : _findString(r, 'videoId');
  if (id == null) return null;
  final cols = r['flexColumns'];
  if (cols is! List || cols.isEmpty) return null;
  String? colText(int i) {
    if (i >= cols.length) return null;
    final c = cols[i];
    return c is Map ? _runsText((c['musicResponsiveListItemFlexColumnRenderer'] as Map?)?['text']) : null;
  }

  final title = colText(0);
  if (title == null || title.isEmpty) return null;
  var groups = <String>[];
  if (cols.length > 1 && cols[1] is Map) {
    final text = (cols[1]['musicResponsiveListItemFlexColumnRenderer'] as Map?)?['text'];
    if (text is Map && text['runs'] is List) groups = _groups(text['runs'] as List);
  }
  final ad = _artistAndDur(groups);
  var dur = ad.dur;
  if (dur == null && r['fixedColumns'] is List) {
    final t = _runsText(((r['fixedColumns'] as List).first as Map)['musicResponsiveListItemFixedColumnRenderer']?['text']);
    if (t != null) dur = _parseDur(t);
  }
  return Track(id: id, title: title, artist: ad.artist, cover: _cover(r['thumbnail']), durationSec: dur);
}

Track? _fromTwoRow(Map r) {
  final id = (((r['navigationEndpoint'] as Map?)?['watchEndpoint']) as Map?)?['videoId'] as String?;
  if (id == null) return null; // album / playlist / artis: bukan lagu
  final title = _runsText(r['title']);
  if (title == null) return null;
  var groups = <String>[];
  final sub = r['subtitle'];
  if (sub is Map && sub['runs'] is List) groups = _groups(sub['runs'] as List);
  final ad = _artistAndDur(groups);
  return Track(id: id, title: title, artist: ad.artist, cover: _cover(r['thumbnailRenderer']), durationSec: ad.dur);
}

Track? _fromPanel(Map r) {
  final id = r['videoId'] as String?;
  final title = _runsText(r['title']);
  if (id == null || title == null) return null;
  var groups = <String>[];
  final by = r['longBylineText'] ?? r['shortBylineText'];
  if (by is Map && by['runs'] is List) groups = _groups(by['runs'] as List);
  final ad = _artistAndDur(groups);
  final dur = _runsText(r['lengthText']);
  return Track(id: id, title: title, artist: ad.artist, cover: _cover(r['thumbnail']), durationSec: dur != null ? _parseDur(dur) : ad.dur);
}

/// Semua lagu di [root] sesuai urutan dokumen, tanpa duplikat.
List<Track> parseTracks(dynamic root) {
  final out = <Track>[];
  final seen = <String>{};
  void add(Track? t) {
    if (t != null && seen.add(t.id)) out.add(t);
  }

  void walk(dynamic n) {
    if (n is Map) {
      if (n['musicResponsiveListItemRenderer'] is Map) {
        add(_fromResponsive(n['musicResponsiveListItemRenderer'] as Map));
        return;
      }
      if (n['musicTwoRowItemRenderer'] is Map) {
        add(_fromTwoRow(n['musicTwoRowItemRenderer'] as Map));
        return;
      }
      if (n['playlistPanelVideoRenderer'] is Map) {
        add(_fromPanel(n['playlistPanelVideoRenderer'] as Map));
        return;
      }
      for (final c in n.values) {
        walk(c);
      }
    } else if (n is List) {
      for (final c in n) {
        walk(c);
      }
    }
  }

  walk(root);
  return out;
}

/// Rak-rak (carousel) di halaman Home / Charts. Rak dengan kurang dari 3 lagu dibuang.
List<Shelf> parseShelves(dynamic root) {
  final out = <Shelf>[];
  void walk(dynamic n) {
    if (n is Map) {
      final shelf = n['musicCarouselShelfRenderer'] ?? n['musicShelfRenderer'];
      if (shelf is Map) {
        final header = (shelf['header'] as Map?)?['musicCarouselShelfBasicHeaderRenderer'];
        final title = _runsText(header is Map ? header['title'] : null) ?? _runsText(shelf['title']) ?? '';
        final tracks = parseTracks(shelf['contents']);
        if (tracks.length >= 3 && title.isNotEmpty) out.add(Shelf(title, tracks));
        return;
      }
      for (final c in n.values) {
        walk(c);
      }
    } else if (n is List) {
      for (final c in n) {
        walk(c);
      }
    }
  }

  walk(root);
  return out;
}
