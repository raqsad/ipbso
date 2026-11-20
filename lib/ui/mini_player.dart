import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'common.dart';

/// Pemutar mini melayang (kaca). Tap = buka kartu Now Playing.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.app, required this.onOpen});
  final AppState app;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final t = app.currentTrack;
        if (t == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Glass(
            radius: 24,
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(children: [
                Cover(t.cover, size: 44, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                    Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: wh(.65))),
                  ]),
                ),
                StreamBuilder<bool>(
                  stream: app.handler.player.playingStream,
                  initialData: app.handler.player.playing,
                  builder: (context, s) => Pressable(
                    onTap: app.handler.togglePlay,
                    child: Icon((s.data ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
                Pressable(onTap: app.handler.skipToNext, child: const Icon(Icons.skip_next_rounded, size: 32, color: Colors.white)),
              ]),
            ),
          ),
        );
      },
    );
  }
}
