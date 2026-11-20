import 'package:flutter/material.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Menu lagu: favorit, putar berikutnya, tambah ke antrean, atau ke playlist.
Future<void> showTrackMenu(BuildContext context, AppState app, Track t) {
  return showBlurCard<void>(context, (c) {
    Widget row(IconData icon, String text, VoidCallback onTap) => Pressable(
          scale: 0.98,
          onTap: () {
            Navigator.of(c).pop();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [Icon(icon, color: Colors.white, size: 22), const SizedBox(width: 14), Expanded(child: Text(text, style: const TextStyle(fontSize: 16, color: Colors.white)))]),
          ),
        );
    return CardShell(
      maxWidth: 340,
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Cover(t.cover, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: wh(.6))),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          row(app.isLiked(t) ? Icons.star_rounded : Icons.star_border_rounded, app.isLiked(t) ? 'Hapus dari favorit' : 'Tambah ke favorit', () => app.toggleLike(t)),
          row(Icons.queue_music_rounded, 'Tambah ke antrean', () {
            app.handler.addToQueueEnd(t);
            toast(context, 'Ditambahkan ke antrean');
          }),
          if (app.playlists.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text('Tambah ke playlist', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: wh(.5)))),
            for (final p in app.playlists)
              row(Icons.playlist_add_rounded, p.name, () {
                app.addToPlaylist(p.id, t);
                toast(context, 'Ditambahkan ke ${p.name}');
              }),
          ],
        ]),
      ),
    );
  });
}
