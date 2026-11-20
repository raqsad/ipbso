import 'package:flutter/material.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'track_menu.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.app});
  final AppState app;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _c = TextEditingController();
  List<Track> _results = [];
  bool _loading = false;
  bool _searched = false;

  AppState get app => widget.app;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _run(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _c.text = query;
    });
    app.addRecentSearch(query);
    try {
      final r = await app.search(query);
      if (mounted) setState(() => _results = r);
    } catch (_) {
      if (mounted) {
        setState(() => _results = []);
        toast(context, 'Pencarian gagal. Cek koneksi internet.');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final curId = app.currentTrack?.id;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 220),
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(22, 24, 20, 16), child: Text('Search', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Glass(
              radius: 28,
              child: SizedBox(
                height: 54,
                child: Row(children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search_rounded, color: wh(.7)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _c,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _run,
                      cursorColor: kMint,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                      decoration: InputDecoration(border: InputBorder.none, hintText: 'Cari lagu, artis, atau album', hintStyle: TextStyle(color: wh(.5))),
                    ),
                  ),
                  if (_c.text.isNotEmpty)
                    Pressable(
                      onTap: () => setState(() {
                        _c.clear();
                        _results = [];
                        _searched = false;
                      }),
                      child: Padding(padding: const EdgeInsets.all(12), child: Icon(Icons.close_rounded, color: wh(.6))),
                    ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: kMint, strokeWidth: 2))),
          if (!_loading && !_searched) ..._recentSearches(),
          if (!_loading && _searched && _results.isEmpty)
            Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('Tidak ada hasil.', style: TextStyle(color: wh(.6))))),
          if (!_loading)
            for (var i = 0; i < _results.length; i++)
              TrackTile(
                _results[i],
                playing: curId == _results[i].id,
                onTap: () => app.playTracks(_results, i),
                trailing: Pressable(
                  onTap: () => showTrackMenu(context, app, _results[i]),
                  child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.more_horiz_rounded, color: wh(.7))),
                ),
              ),
        ],
      ),
    );
  }

  List<Widget> _recentSearches() {
    if (app.recentSearches.isEmpty) return const [];
    return [
      SectionHeader('Pencarian terakhir', trailing: Pressable(onTap: app.clearRecentSearches, child: Text('Hapus', style: TextStyle(fontSize: 13, color: wh(.6))))),
      for (final s in app.recentSearches)
        Pressable(
          scale: 0.98,
          onTap: () => _run(s),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Row(children: [Icon(Icons.history_rounded, size: 20, color: wh(.55)), const SizedBox(width: 14), Expanded(child: Text(s, style: const TextStyle(fontSize: 16, color: Colors.white)))]),
          ),
        ),
    ];
  }
}
