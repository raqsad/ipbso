import 'package:flutter/material.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Isi satu playlist, atau daftar Lagu Favorit ([playlist] null + [likedMode] true).
class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key, required this.app, this.playlistId, this.likedMode = false});
  final AppState app;
  final String? playlistId;
  final bool likedMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final pl = likedMode ? null : app.playlists.where((p) => p.id == playlistId).firstOrNull;
          final tracks = likedMode ? app.liked : (pl?.tracks ?? const <Track>[]);
          final title = likedMode ? 'Lagu Favorit' : (pl?.name ?? 'Playlist');
          final curId = app.currentTrack?.id;
          return SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(children: [
                    Pressable(onTap: () => Navigator.of(context).pop(), child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white))),
                    const Spacer(),
                    if (!likedMode && pl != null)
                      Pressable(
                        onTap: () {
                          app.deletePlaylist(pl.id);
                          Navigator.of(context).pop();
                        },
                        child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.delete_outline_rounded, color: wh(.8))),
                      ),
                  ]),
                ),
                Center(
                  child: tracks.isEmpty && likedMode
                      ? Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kAccent, kViolet])),
                          child: const Icon(Icons.favorite_rounded, size: 64, color: Colors.white),
                        )
                      : Cover(tracks.isEmpty ? null : tracks.first.cover, size: 180, radius: 24),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(children: [
                    Text(title, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('${tracks.length} lagu', style: TextStyle(fontSize: 14, color: wh(.6))),
                  ]),
                ),
                const SizedBox(height: 16),
                if (tracks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(children: [
                      Expanded(child: _action(Icons.play_arrow_rounded, 'Putar', true, () => app.playTracks(tracks, 0))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _action(Icons.shuffle_rounded, 'Acak', false, () {
                          final s = List<Track>.of(tracks)..shuffle();
                          app.playTracks(s, 0);
                        }),
                      ),
                    ]),
                  ),
                const SizedBox(height: 12),
                if (tracks.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('Belum ada lagu.', style: TextStyle(color: wh(.6))))),
                for (var i = 0; i < tracks.length; i++)
                  TrackTile(
                    tracks[i],
                    playing: curId == tracks[i].id,
                    onTap: () => app.playTracks(tracks, i),
                    trailing: Pressable(
                      onTap: () {
                        if (likedMode) {
                          app.toggleLike(tracks[i]);
                        } else if (pl != null) {
                          app.removeFromPlaylist(pl.id, tracks[i].id);
                        }
                      },
                      child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close_rounded, color: wh(.6))),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _action(IconData icon, String text, bool filled, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(color: filled ? Colors.white : wh(.14), borderRadius: BorderRadius.circular(50)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20, color: filled ? Colors.black : Colors.white),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: filled ? Colors.black : Colors.white)),
        ]),
      ),
    );
  }
}
