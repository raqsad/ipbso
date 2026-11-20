import 'package:flutter/material.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'import_dialog.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.app, required this.onOpenPlaylist, required this.onOpenLiked});
  final AppState app;
  final void Function(PlaylistData) onOpenPlaylist;
  final VoidCallback onOpenLiked;

  Future<void> _create(BuildContext context) async {
    final c = TextEditingController();
    await showBlurCard<void>(context, (dc) {
      return CardShell(
        maxWidth: 340,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Playlist baru', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: wh(.3))),
            child: TextField(
              controller: c,
              autofocus: true,
              cursorColor: kMint,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(border: InputBorder.none, hintText: 'Nama playlist', hintStyle: TextStyle(color: wh(.45))),
            ),
          ),
          const SizedBox(height: 14),
          Pressable(
            onTap: () {
              app.createPlaylist(c.text);
              Navigator.of(dc).pop();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(50)),
              alignment: Alignment.center,
              child: const Text('Buat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black)),
            ),
          ),
        ]),
      );
    });
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 220),
          children: [
            Row(children: [
              const Expanded(child: Text('Library', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white))),
              GlassIconButton(Icons.cloud_download_rounded, size: 44, onTap: () => showImportCard(context, app, onOpen: onOpenPlaylist)),
              const SizedBox(width: 10),
              GlassIconButton(Icons.add_rounded, size: 44, onTap: () => _create(context)),
            ]),
            const SizedBox(height: 20),
            _row(
              leading: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kAccent, kViolet])),
                child: const Icon(Icons.favorite_rounded, color: Colors.white),
              ),
              title: 'Lagu Favorit',
              sub: '${app.liked.length} lagu',
              onTap: onOpenLiked,
            ),
            _row(
              leading: Container(width: 52, height: 52, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: wh(.1)), child: const Icon(Icons.cloud_download_rounded, color: kMint)),
              title: 'Import Playlist',
              sub: 'Dari Spotify, Deezer, YouTube, atau file',
              onTap: () => showImportCard(context, app, onOpen: onOpenPlaylist),
            ),
            for (final p in app.playlists)
              _row(leading: Cover(p.cover, size: 52), title: p.name, sub: '${p.tracks.length} lagu', onTap: () => onOpenPlaylist(p)),
            if (app.playlists.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 24), child: Center(child: Text('Belum ada playlist. Buat baru atau import dari Spotify.', textAlign: TextAlign.center, style: TextStyle(color: wh(.55))))),
          ],
        ),
      ),
    );
  }

  Widget _row({required Widget leading, required String title, required String sub, required VoidCallback onTap}) {
    return Pressable(
      scale: 0.98,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
              Text(sub, style: TextStyle(fontSize: 12, color: wh(.6))),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: wh(.4)),
        ]),
      ),
    );
  }
}
