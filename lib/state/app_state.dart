import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';
import '../services/importer.dart';
import '../services/raq_audio_handler.dart';
import '../services/ytm_client.dart';

/// Semua data & aksi app: library lokal, Home, pencarian, antrean pintar, sleep timer, dan import.
class AppState extends ChangeNotifier {
  AppState(this.handler) {
    importer = PlaylistImporter(ytm: ytm, save: savePlaylist);
  }

  final RaqAudioHandler handler;
  final YtmClient ytm = YtmClient();
  late final PlaylistImporter importer;
  late SharedPreferences _p;

  // ---- data
  List<Shelf> shelves = [];
  List<Track> trending = [];
  List<Track> recent = [];
  List<Track> liked = [];
  List<PlaylistData> playlists = [];
  List<String> recentSearches = [];
  bool homeLoading = false;

  // ---- pengaturan
  int crossfadeSec = 0;
  bool smartMix = false;
  final Set<String> smartIds = <String>{};
  DateTime? sleepEnd;
  Timer? _sleepTimer;
  Timer? _homeTimer;
  bool _smartBusy = false;

  Track? get currentTrack => handler.current;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    recent = _readTracks('recent');
    liked = _readTracks('liked');
    recentSearches = _p.getStringList('searches') ?? [];
    playlists = (_p.getStringList('playlists') ?? [])
        .map((s) => PlaylistData.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map)))
        .toList();
    crossfadeSec = _p.getInt('crossfade') ?? 0;
    smartMix = _p.getBool('smartmix') ?? false;
    handler.fadeSec = crossfadeSec;
    handler.onNeedMore = (seed) => ytm.related(seed.id);

    int lastIndex = handler.currentIndex.value;
    handler.currentIndex.addListener(() {
      final i = handler.currentIndex.value;
      if (i != lastIndex) {
        lastIndex = i;
        final t = handler.current;
        if (t != null) _pushRecent(t);
        if (smartMix) unawaited(_topUpSmart());
      }
      notifyListeners();
    });
    handler.queueTracks.addListener(notifyListeners);
    handler.shuffle.addListener(notifyListeners);
    handler.repeat.addListener(notifyListeners);

    unawaited(loadHome());
    _homeTimer = Timer.periodic(const Duration(minutes: 30), (_) => unawaited(loadHome()));
  }

  List<Track> _readTracks(String key) => (_p.getStringList(key) ?? [])
      .map((s) => Track.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map)))
      .toList();

  Future<void> _writeTracks(String key, List<Track> list) =>
      _p.setStringList(key, list.map((t) => jsonEncode(t.toJson())).toList());

  Future<void> _writePlaylists() => _p.setStringList('playlists', playlists.map((x) => jsonEncode(x.toJson())).toList());

  // ------------------------------------------------------------------------------------------ Home
  Future<void> loadHome() async {
    if (homeLoading) return;
    homeLoading = true;
    notifyListeners();
    final out = <Shelf>[];
    List<Track> chartTop = [];
    try {
      for (final s in await ytm.charts()) {
        out.add(s);
        final k = s.title.toLowerCase();
        if (chartTop.isEmpty && (k.contains('lagu') || k.contains('song') || k.contains('top'))) chartTop = s.tracks;
      }
    } catch (_) {}
    try {
      out.addAll(await ytm.home());
    } catch (_) {}
    if (recent.isNotEmpty) {
      try {
        final seed = recent.first;
        final similar = await ytm.related(seed.id);
        if (similar.length >= 3) out.insert(0, Shelf('Mirip dengan ${seed.title}', similar));
      } catch (_) {}
    }
    if (out.isNotEmpty) {
      final seen = <String>{};
      shelves = out.where((s) => seen.add(s.title)).toList();
    }
    if (chartTop.isNotEmpty) {
      trending = chartTop.take(10).toList();
    } else if (trending.isEmpty) {
      try {
        trending = (await ytm.searchSongs('top hits')).take(10).toList();
      } catch (_) {}
    }
    homeLoading = false;
    notifyListeners();
  }

  /// Artis teratas: dari riwayat putar (bobot 3x) + isi rak Home.
  List<({String name, String? cover, List<Track> tracks})> get topArtists {
    String main(Track t) => t.artist.split(RegExp(r'[,&]')).first.trim();
    final all = [...recent, ...shelves.expand((s) => s.tracks)].where((t) => main(t).isNotEmpty);
    final recentCount = <String, int>{};
    for (final t in recent) {
      recentCount[main(t)] = (recentCount[main(t)] ?? 0) + 1;
    }
    final groups = <String, List<Track>>{};
    for (final t in all) {
      groups.putIfAbsent(main(t), () => []).add(t);
    }
    final list = groups.entries.map((e) {
      final seen = <String>{};
      final tracks = e.value.where((t) => seen.add(t.id)).toList();
      final cover = tracks.map((t) => t.cover).whereType<String>().firstOrNull;
      return (name: e.key, cover: cover, tracks: tracks);
    }).toList()
      ..sort((a, b) => ((recentCount[b.name] ?? 0) * 3 + b.tracks.length).compareTo((recentCount[a.name] ?? 0) * 3 + a.tracks.length));
    return list.take(12).toList();
  }

  // ------------------------------------------------------------------------------------------ pemutaran
  Future<void> playTracks(List<Track> list, int index) => handler.playQueue(list, index);

  void _pushRecent(Track t) {
    recent = [t, ...recent.where((x) => x.id != t.id)].take(50).toList();
    _writeTracks('recent', recent);
  }

  static final _notSong = RegExp(r'(\d+\s*(hour|hours|jam)|\bmix\b|compilation|playlist|background|no copyright|royalty|full album|non[- ]?stop)', caseSensitive: false);

  /// Mood: cari lagu lalu putar; lagu lebih dari 10 menit & mix/kompilasi dibuang.
  Future<bool> playMood(String query) async {
    try {
      final r = await ytm.searchSongs(query);
      final short = r.where((t) => (t.durationSec ?? 0) <= 600).toList();
      final clean = short.where((t) => !_notSong.hasMatch(t.title)).toList();
      final songs = (clean.length >= 3 ? clean : short).take(30).toList();
      if (songs.isEmpty) return false;
      await playTracks(songs, 0);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Track>> search(String q) => ytm.searchSongs(q);

  void addRecentSearch(String q) {
    final s = q.trim();
    if (s.isEmpty) return;
    recentSearches = [s, ...recentSearches.where((x) => x.toLowerCase() != s.toLowerCase())].take(10).toList();
    _p.setStringList('searches', recentSearches);
    notifyListeners();
  }

  void clearRecentSearches() {
    recentSearches = [];
    _p.setStringList('searches', recentSearches);
    notifyListeners();
  }

  // ------------------------------------------------------------------------------------------ library
  bool isLiked(Track t) => liked.any((x) => x.id == t.id);

  void toggleLike(Track t) {
    liked = isLiked(t) ? liked.where((x) => x.id != t.id).toList() : [t, ...liked];
    _writeTracks('liked', liked);
    notifyListeners();
  }

  PlaylistData createPlaylist(String name) {
    final pl = PlaylistData(id: 'pl_${DateTime.now().microsecondsSinceEpoch}', name: name.trim().isEmpty ? 'Playlist baru' : name.trim());
    playlists = [...playlists, pl];
    _writePlaylists();
    notifyListeners();
    return pl;
  }

  Future<PlaylistData> savePlaylist(String name, List<Track> tracks) async {
    final pl = PlaylistData(id: 'pl_${DateTime.now().microsecondsSinceEpoch}', name: name.trim().isEmpty ? 'Playlist import' : name.trim(), tracks: tracks);
    playlists = [...playlists, pl];
    await _writePlaylists();
    notifyListeners();
    return pl;
  }

  void deletePlaylist(String id) {
    playlists = playlists.where((p) => p.id != id).toList();
    _writePlaylists();
    notifyListeners();
  }

  void addToPlaylist(String pid, Track t) {
    final pl = playlists.where((p) => p.id == pid).firstOrNull;
    if (pl == null || pl.tracks.any((x) => x.id == t.id)) return;
    pl.tracks.add(t);
    _writePlaylists();
    notifyListeners();
  }

  void removeFromPlaylist(String pid, String trackId) {
    final pl = playlists.where((p) => p.id == pid).firstOrNull;
    if (pl == null) return;
    pl.tracks.removeWhere((t) => t.id == trackId);
    _writePlaylists();
    notifyListeners();
  }

  // ------------------------------------------------------------------------------------------ antrean pintar & fade
  void setCrossfade(int sec) {
    crossfadeSec = sec;
    handler.fadeSec = sec;
    _p.setInt('crossfade', sec);
    notifyListeners();
  }

  void setSmartMix(bool on) {
    smartMix = on;
    _p.setBool('smartmix', on);
    if (on) {
      unawaited(_topUpSmart());
    } else {
      // Matikan: buang rekomendasi yang belum diputar, lagu pilihan kamu tidak disentuh.
      final cur = handler.currentIndex.value;
      final list = handler.tracks;
      for (var i = list.length - 1; i > cur; i--) {
        if (smartIds.contains(list[i].id)) handler.removeAt(i);
      }
      smartIds.clear();
    }
    notifyListeners();
  }

  Future<void> _topUpSmart() async {
    if (!smartMix || _smartBusy) return;
    _smartBusy = true;
    try {
      final q = handler.tracks;
      final cur = handler.currentIndex.value;
      if (cur < 0 || cur >= q.length) return;
      final upcomingRec = q.skip(cur + 1).where((t) => smartIds.contains(t.id)).length;
      if (upcomingRec >= 3) return;
      final recs = await ytm.related(q[cur].id);
      final have = handler.tracks.map((t) => t.id).toSet();
      final fresh = recs.where((t) => !have.contains(t.id)).take(5).toList();
      if (fresh.isEmpty) return;
      handler.insertSmart(fresh);
      smartIds.addAll(fresh.map((t) => t.id));
      notifyListeners();
    } catch (_) {
      // jaringan gagal: coba lagi di pergantian lagu berikutnya
    } finally {
      _smartBusy = false;
    }
  }

  // ------------------------------------------------------------------------------------------ sleep timer
  void startSleep(int minutes) {
    _sleepTimer?.cancel();
    sleepEnd = DateTime.now().add(Duration(minutes: minutes));
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      if (handler.player.playing) handler.pause();
      sleepEnd = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleep() {
    _sleepTimer?.cancel();
    sleepEnd = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _homeTimer?.cancel();
    super.dispose();
  }
}
