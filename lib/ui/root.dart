import 'package:flutter/material.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'mini_player.dart';
import 'now_playing_card.dart';
import 'player_screen.dart';
import 'playlist_screen.dart';
import 'queue_screen.dart';
import 'search_screen.dart';

/// Kerangka utama: tiga tab, plus pemutar mini dan bar navigasi kaca yang melayang di atas konten.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key, required this.app});
  final AppState app;

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _tab = 0;

  AppState get app => widget.app;

  void _push(Widget page, {bool fullscreen = false}) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page, fullscreenDialog: fullscreen));
  }

  void _openPlaylist(PlaylistData p) => _push(PlaylistScreen(app: app, playlistId: p.id));
  void _openLiked() => _push(PlaylistScreen(app: app, likedMode: true));
  void _openQueue() => _push(QueueScreen(app: app), fullscreen: true);
  void _openFull() => _push(PlayerScreen(app: app, onQueue: _openQueue), fullscreen: true);
  void _openCard() => showNowPlayingCard(context, app, onOpenFull: _openFull, onQueue: _openQueue);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: IndexedStack(index: _tab, children: [
            HomeScreen(app: app, onSearch: () => setState(() => _tab = 1), onOpenPlaylist: _openPlaylist, onOpenLiked: _openLiked),
            SearchScreen(app: app),
            LibraryScreen(app: app, onOpenPlaylist: _openPlaylist, onOpenLiked: _openLiked),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, bk(.55)])),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                MiniPlayer(app: app, onOpen: _openCard),
                _NavBar(index: _tab, onSelect: (i) => setState(() => _tab = i)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.search_rounded, 'Search'),
    (Icons.library_music_rounded, 'Library'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Glass(
        radius: 30,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            for (var i = 0; i < _items.length; i++)
              Pressable(
                scale: 0.9,
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: index == i ? wh(.16) : Colors.transparent),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_items[i].$1, size: 26, color: index == i ? Colors.white : wh(.6)),
                    const SizedBox(height: 2),
                    Text(_items[i].$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: index == i ? Colors.white : wh(.6))),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
