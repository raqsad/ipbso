import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'common.dart';
import 'player_widgets.dart';
import 'sleep_dialog.dart';

/// Kartu "sedang diputar" ala Control Center iPhone; latar di belakangnya di-blur.
Future<void> showNowPlayingCard(BuildContext context, AppState app, {required VoidCallback onOpenFull, required VoidCallback onQueue}) {
  return showBlurCard<void>(context, (c) {
    return CardShell(
      radius: 38,
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final t = app.currentTrack;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Pressable(
              scale: 0.98,
              onTap: () {
                Navigator.of(c).pop();
                onOpenFull();
              },
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(borderRadius: BorderRadius.circular(26), child: CoverFill(t?.cover)),
              ),
            ),
            const SizedBox(height: 18),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Now Playing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: wh(.5))),
                  Text(t?.title ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(t?.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, color: wh(.6))),
                ]),
              ),
              Pressable(
                onTap: () => showSleepDialog(context, app),
                child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.bedtime_rounded, size: 26, color: wh(.85))),
              ),
              Pressable(
                onTap: () {
                  if (t != null) app.toggleLike(t);
                },
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    t != null && app.isLiked(t) ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 28,
                    color: t != null && app.isLiked(t) ? const Color(0xFFFFD54F) : wh(.85),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            ProgressBar(handler: app.handler),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TransportRow(handler: app.handler)),
              Pressable(
                onTap: () {
                  Navigator.of(c).pop();
                  onQueue();
                },
                child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.queue_music_rounded, size: 26, color: wh(.8))),
              ),
            ]),
            const SizedBox(height: 12),
            VolumeBar(handler: app.handler),
          ]);
        },
      ),
    );
  });
}
