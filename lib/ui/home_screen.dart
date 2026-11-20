import 'package:flutter/material.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'about_dialog.dart';
import 'common.dart';
import 'sleep_dialog.dart';

class _Mood {
  const _Mood(this.label, this.icon, this.query, this.c1, this.c2);
  final String label;
  final IconData icon;
  final String query;
  final Color c1;
  final Color c2;
}

const _moods = [
  _Mood('Chill', Icons.spa_rounded, 'lagu santai chill populer', Color(0xFF2DE2C0), Color(0xFF0B6E7A)),
  _Mood('Workout', Icons.fitness_center_rounded, 'best workout songs 2026', Color(0xFFFA2D48), Color(0xFF8A1030)),
  _Mood('Party', Icons.celebration_rounded, 'party songs hits 2026', Color(0xFFFF8A3D), Color(0xFFC21E56)),
  _Mood('Focus', Icons.headphones_rounded, 'lagu enak buat fokus kerja', Color(0xFF4C6FFF), Color(0xFF1B2A7A)),
  _Mood('Hits', Icons.local_fire_department_rounded, 'lagu hits terbaru 2026', Color(0xFFFFC53D), Color(0xFFE0601C)),
  _Mood('Sleep', Icons.bedtime_rounded, 'lagu pengantar tidur tenang', Color(0xFF7C3AED), Color(0xFF2B1260)),
  _Mood('Late Night', Icons.nightlife_rounded, 'lagu galau malam hari', Color(0xFF4A4A78), Color(0xFF12121F)),
];

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 5) return 'Good Night,';
  if (h < 12) return 'Good Morning,';
  if (h < 15) return 'Good Afternoon,';
  if (h < 19) return 'Good Evening,';
  return 'Good Night,';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.app, required this.onSearch, required this.onOpenPlaylist, required this.onOpenLiked});
  final AppState app;
  final VoidCallback onSearch;
  final void Function(PlaylistData) onOpenPlaylist;
  final VoidCallback onOpenLiked;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showAllTop = false;
  String? _loadingMood;

  AppState get app => widget.app;

  Future<void> _playMood(_Mood m) async {
    if (_loadingMood != null) return;
    setState(() => _loadingMood = m.label);
    final ok = await app.playMood(m.query);
    if (!mounted) return;
    setState(() => _loadingMood = null);
    if (!ok) toast(context, 'Gagal memuat ${m.label}');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 460,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(center: const Alignment(0.9, -1), radius: 1.0, colors: [kAccent.withAlpha(51), Colors.transparent]),
            ),
          ),
        ),
      ),
      ListenableBuilder(
        listenable: app,
        builder: (context, _) => RefreshIndicator(
          onRefresh: app.loadHome,
          color: kMint,
          backgroundColor: const Color(0xFF2C2C2E),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 220),
            children: [
              _header(context),
              _searchBar(),
              const SizedBox(height: 20),
              ..._quick(context),
              ..._topArtists(),
              ..._topSongs(),
              ..._moodSection(),
              ..._recent(),
              ..._shelves(),
              if (app.shelves.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: app.homeLoading
                        ? const CircularProgressIndicator(color: kMint, strokeWidth: 2)
                        : Text('Tidak bisa memuat lagu. Tarik ke bawah untuk coba lagi.', textAlign: TextAlign.center, style: TextStyle(color: wh(.6))),
                  ),
                ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _header(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 20, 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(), style: TextStyle(fontSize: 22, color: wh(.85))),
              const Text('Raq \u{1F44B}', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
          GlassIconButton(Icons.refresh_rounded, size: 44, onTap: () {
            app.loadHome();
            toast(context, 'Memuat ulang lagu...');
          }),
          const SizedBox(width: 10),
          GlassIconButton(Icons.bedtime_rounded, size: 44, dot: app.sleepEnd != null, onTap: () => showSleepDialog(context, app)),
          const SizedBox(width: 10),
          GlassIconButton(Icons.info_outline_rounded, size: 44, onTap: () => showAboutCard(context)),
        ]),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Glass(
        radius: 28,
        onTap: widget.onSearch,
        child: SizedBox(
          height: 54,
          child: Row(children: [
            const SizedBox(width: 16),
            Icon(Icons.search_rounded, color: wh(.7)),
            const SizedBox(width: 12),
            Text('Cari lagu, artis, atau album', style: TextStyle(fontSize: 16, color: wh(.55))),
          ]),
        ),
      ),
    );
  }

  List<Widget> _quick(BuildContext context) {
    final tiles = <Widget>[];
    if (app.liked.isNotEmpty) {
      tiles.add(_quickTile(
        name: 'Lagu Favorit',
        icon: Icons.favorite_rounded,
        gradient: const [kAccent, kViolet],
        onTap: widget.onOpenLiked,
      ));
    }
    for (final p in app.playlists.take(5)) {
      tiles.add(_quickTile(name: p.name, cover: p.cover, onTap: () => widget.onOpenPlaylist(p)));
    }
    if (tiles.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
        }),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _quickTile({required String name, String? cover, IconData? icon, List<Color>? gradient, required VoidCallback onTap}) {
    return Glass(
      radius: 18,
      onTap: onTap,
      child: SizedBox(
        height: 62,
        child: Row(children: [
          SizedBox(
            width: 62,
            height: 62,
            child: icon != null
                ? DecoratedBox(
                    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient!)),
                    child: Icon(icon, color: Colors.white),
                  )
                : Cover(cover, size: 62, radius: 0),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _topArtists() {
    final artists = app.topArtists;
    if (artists.isEmpty) return const [];
    return [
      const SectionHeader('Top Artists'),
      SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: artists.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (context, i) {
            final a = artists[i];
            return Pressable(
              onTap: () => app.playTracks(a.tracks, 0),
              child: SizedBox(
                width: 92,
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: wh(.18))),
                    child: Cover(a.cover, size: 86, radius: 43),
                  ),
                  const SizedBox(height: 8),
                  Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text('Artist', style: TextStyle(fontSize: 11, color: wh(.5))),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  List<Widget> _topSongs() {
    final songs = <Track>[];
    final seen = <String>{};
    for (final t in [...app.trending, ...app.shelves.expand((s) => s.tracks)]) {
      if (seen.add(t.id)) songs.add(t);
      if (songs.length >= 10) break;
    }
    if (songs.isEmpty) return const [];
    final shown = songs.take(_showAllTop ? 10 : 5).toList();
    final curId = app.currentTrack?.id;
    return [
      const SectionHeader('Top Songs'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Glass(
          radius: 22,
          child: Column(children: [
            const SizedBox(height: 6),
            for (var i = 0; i < shown.length; i++) TrackTile(shown[i], rank: i + 1, playing: curId == shown[i].id, onTap: () => app.playTracks(songs, i)),
            if (songs.length > 5)
              Pressable(
                scale: 0.98,
                onTap: () => setState(() => _showAllTop = !_showAllTop),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_showAllTop ? 'Show less' : 'Show more', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: wh(.7))),
                  ),
                ),
              ),
            const SizedBox(height: 4),
          ]),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _moodSection() {
    return [
      const SectionHeader('Browse by Mood'),
      SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _moods.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final m = _moods[i];
            return Pressable(
              onTap: () => _playMood(m),
              child: Container(
                width: 136,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [m.c1, m.c2])),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  Positioned(right: 8, bottom: 8, child: Icon(m.icon, size: 44, color: wh(.28))),
                  Positioned(left: 14, top: 14, child: Text(m.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
                  if (_loadingMood == m.label)
                    const Positioned(left: 14, bottom: 14, child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _recent() {
    final curId = app.currentTrack?.id;
    return [
      const SectionHeader('Recently Played'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Glass(
          radius: 22,
          child: app.recent.isEmpty
              ? Padding(padding: const EdgeInsets.all(16), child: Text('Belum ada riwayat. Putar lagu dulu.', style: TextStyle(fontSize: 13, color: wh(.6))))
              : Column(children: [
                  const SizedBox(height: 6),
                  for (var i = 0; i < app.recent.take(5).length; i++)
                    TrackTile(app.recent[i], playing: curId == app.recent[i].id, onTap: () => app.playTracks(app.recent, i)),
                  const SizedBox(height: 6),
                ]),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _shelves() {
    return [
      for (final shelf in app.shelves) ...[
        SectionHeader(shelf.title),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: shelf.tracks.length.clamp(0, 20),
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final t = shelf.tracks[i];
              return Pressable(
                onTap: () => app.playTracks(shelf.tracks, i),
                child: SizedBox(
                  width: 140,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Stack(children: [
                      Cover(t.cover, size: 140, radius: 16),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Glass(radius: 16, child: const SizedBox(width: 32, height: 32, child: Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white))),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                    Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: wh(.6))),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }
}
