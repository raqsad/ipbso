import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../core/import_parse.dart';
import '../core/models.dart';
import 'ytm_client.dart';

enum ImportPhase { idle, reading, matching, done, error }

class ImportState {
  final ImportPhase phase;
  final String name;
  final int done;
  final int total;
  final int matched;
  final String message;
  final String? playlistId;
  final int playlistCount;
  final String? cover;

  const ImportState({
    this.phase = ImportPhase.idle,
    this.name = '',
    this.done = 0,
    this.total = 0,
    this.matched = 0,
    this.message = '',
    this.playlistId,
    this.playlistCount = 0,
    this.cover,
  });
}

/// Memindahkan playlist dari luar (Spotify, Deezer, YouTube, file CSV/JSON/M3U/TXT) ke library app.
class PlaylistImporter {
  PlaylistImporter({required this.ytm, required this.save});

  final YtmClient ytm;
  final Future<PlaylistData> Function(String name, List<Track> tracks) save;
  final ValueNotifier<ImportState> state = ValueNotifier<ImportState>(const ImportState());
  final http.Client _http = http.Client();
  int _gen = 0;

  static const _ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  bool get running => state.value.phase == ImportPhase.reading || state.value.phase == ImportPhase.matching;

  void cancel() {
    _gen++;
    state.value = const ImportState();
  }

  void reset() {
    if (!running) state.value = const ImportState();
  }

  void _fail(String msg) => state.value = ImportState(phase: ImportPhase.error, message: msg);

  Future<void> fromUrl(String raw) async {
    final gen = ++_gen;
    final url = raw.trim();
    state.value = const ImportState(phase: ImportPhase.reading, message: 'Membaca playlist...');
    try {
      switch (ImportParsers.kindOf(url)) {
        case LinkKind.spotify:
          final ref = ImportParsers.spotifyRef(url);
          if (ref == null) return _fail('Link Spotify tidak dikenali. Pakai link playlist atau album.');
          final html = await _get('https://open.spotify.com/embed/${ref.$1}/${ref.$2}');
          if (html == null) return _fail('Tidak bisa membuka Spotify. Cek koneksi internet.');
          final list = ImportParsers.spotifyEmbed(html);
          if (list == null) {
            return _fail('Playlist tidak terbaca (mungkin privat). Ekspor ke CSV lewat exportify.net lalu pilih filenya.');
          }
          await _matchAndSave(gen, [list]);
        case LinkKind.deezer:
          final id = await _deezerId(url);
          if (id == null) return _fail('Link Deezer tidak dikenali.');
          final list = await _deezerList(id);
          if (list == null) return _fail('Playlist Deezer tidak terbaca (mungkin privat).');
          await _matchAndSave(gen, [list]);
        case LinkKind.youtube:
          final id = ImportParsers.youtubeListId(url);
          if (id == null) return _fail('Link YouTube harus berupa playlist (ada ?list=...).');
          await _youtubeDirect(gen, id);
        case LinkKind.unknown:
          _fail('Link belum didukung. Untuk Apple Music, Tidal, dan lainnya: ekspor ke CSV (tunemymusic.com / soundiiz.com) lalu pilih filenya.');
      }
    } catch (e) {
      if (gen == _gen) _fail('Gagal: $e');
    }
  }

  Future<void> fromText(String defaultName, String text) async {
    final gen = ++_gen;
    state.value = const ImportState(phase: ImportPhase.reading, message: 'Membaca file...');
    try {
      final lists = ImportParsers.parseText(defaultName, text);
      if (lists.isEmpty) return _fail('Isi file tidak terbaca. Pakai CSV, JSON, M3U, atau daftar lagu per baris.');
      await _matchAndSave(gen, lists);
    } catch (e) {
      if (gen == _gen) _fail('Gagal: $e');
    }
  }

  // ------------------------------------------------------------------------------------------ inti
  Future<void> _matchAndSave(int gen, List<ImportedList> lists) async {
    final total = lists.fold<int>(0, (s, l) => s + l.tracks.length);
    var done = 0;
    var matchedAll = 0;
    var saved = 0;
    PlaylistData? first;
    for (final list in lists) {
      final found = <Track?>[];
      for (var i = 0; i < list.tracks.length; i += 4) {
        if (gen != _gen) return; // dibatalkan
        final chunk = list.tracks.skip(i).take(4).toList();
        found.addAll(await Future.wait(chunk.map(_find)));
        done += chunk.length;
        state.value = ImportState(
          phase: ImportPhase.matching,
          name: list.name,
          done: done,
          total: total,
          matched: matchedAll + found.whereType<Track>().length,
          message: 'Mencocokkan lagu...',
        );
      }
      final seen = <String>{};
      final tracks = found.whereType<Track>().where((t) => seen.add(t.id)).toList();
      matchedAll += tracks.length;
      if (tracks.isEmpty) continue;
      final pl = await save(list.name, tracks);
      saved++;
      first ??= pl;
    }
    if (gen != _gen) return;
    if (saved == 0 || first == null) {
      _fail('Tidak ada lagu yang cocok di YouTube Music. Cek isi file atau linknya.');
    } else {
      state.value = ImportState(
        phase: ImportPhase.done,
        name: first.name,
        done: total,
        total: total,
        matched: matchedAll,
        playlistId: first.id,
        playlistCount: saved,
        cover: first.cover,
        message: saved > 1 ? '$saved playlist dibuat.' : 'Playlist "${first.name}" dibuat.',
      );
    }
  }

  Future<Track?> _find(ImportedTrack t) async {
    try {
      final q = t.artist.isEmpty ? t.title : '${t.title} ${t.artist}';
      final res = await ytm.searchSongs(q);
      final picked = ImportParsers.pick(res.map((x) => Cand(x.title, x.artist, x)).toList(), t);
      return picked?.ref as Track?;
    } catch (_) {
      return null;
    }
  }

  /// Link YouTube / YouTube Music: lagunya sudah dari YouTube, tidak perlu dicocokkan.
  Future<void> _youtubeDirect(int gen, String listId) async {
    final yt = YoutubeExplode();
    try {
      final pl = await yt.playlists.get(listId);
      state.value = ImportState(phase: ImportPhase.reading, name: pl.title, message: 'Mengambil lagu...');
      final vids = await yt.playlists.getVideos(listId).take(500).toList();
      if (gen != _gen) return;
      final seen = <String>{};
      final tracks = <Track>[];
      for (final v in vids) {
        if (!seen.add(v.id.value)) continue;
        tracks.add(Track(
          id: v.id.value,
          title: v.title,
          artist: v.author.replaceAll(' - Topic', ''),
          cover: v.thumbnails.highResUrl,
          durationSec: v.duration?.inSeconds,
        ));
      }
      if (tracks.isEmpty) return _fail('Playlist kosong atau tidak bisa dibaca.');
      final saved = await save(pl.title, tracks);
      state.value = ImportState(
        phase: ImportPhase.done,
        name: saved.name,
        done: tracks.length,
        total: tracks.length,
        matched: tracks.length,
        playlistId: saved.id,
        playlistCount: 1,
        cover: saved.cover,
        message: 'Playlist "${saved.name}" dibuat.',
      );
    } finally {
      yt.close();
    }
  }

  // ------------------------------------------------------------------------------------------ jaringan
  Future<String?> _get(String url) async {
    try {
      final r = await _http
          .get(Uri.parse(url), headers: {'User-Agent': _ua, 'Accept-Language': 'en-US,en;q=0.9'})
          .timeout(const Duration(seconds: 20));
      return r.statusCode >= 200 && r.statusCode < 300 ? utf8.decode(r.bodyBytes) : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _deezerId(String url) async {
    final direct = ImportParsers.deezerPlaylistId(url);
    if (direct != null) return direct;
    try {
      // Link pendek (link.deezer.com/...) diarahkan ulang ke link panjang.
      final req = http.Request('GET', Uri.parse(url))..followRedirects = false;
      final res = await _http.send(req).timeout(const Duration(seconds: 10));
      return ImportParsers.deezerPlaylistId(res.headers['location'] ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<ImportedList?> _deezerList(String id) async {
    final metaText = await _get('https://api.deezer.com/playlist/$id');
    if (metaText == null) return null;
    final meta = jsonDecode(metaText);
    if (meta is! Map || meta.containsKey('error')) return null;
    final name = (meta['title'] as String?)?.trim();
    final tracks = <ImportedTrack>[];
    var index = 0;
    while (index < 1000) {
      final pageText = await _get('https://api.deezer.com/playlist/$id/tracks?limit=100&index=$index');
      if (pageText == null) break;
      final page = jsonDecode(pageText);
      if (page is! Map || page['data'] is! List) break;
      final data = page['data'] as List;
      if (data.isEmpty) break;
      for (final o in data) {
        if (o is! Map) continue;
        final t = (o['title'] as String? ?? '').trim();
        final a = o['artist'] is Map ? ((o['artist'] as Map)['name'] as String? ?? '') : '';
        if (t.isNotEmpty) tracks.add(ImportedTrack(t, a));
      }
      if (!page.containsKey('next')) break;
      index += 100;
    }
    return tracks.isEmpty ? null : ImportedList(name == null || name.isEmpty ? 'Playlist Deezer' : name, tracks);
  }
}
