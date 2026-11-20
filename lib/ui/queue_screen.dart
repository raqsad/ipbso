import 'package:flutter/material.dart';

import '../core/models.dart';
import '../services/raq_audio_handler.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Antrean: Smart Mix, transisi mulus, dan daftar lagu (sedang diputar / berikutnya / sudah diputar).
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key, required this.app});
  final AppState app;

  RaqAudioHandler get h => app.handler;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([app, h.queueTracks, h.currentIndex, h.shuffle, h.repeat]),
          builder: (context, _) {
            final q = h.queueTracks.value;
            final cur = h.currentIndex.value;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
                child: Row(children: [
                  Pressable(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Antrean', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('${q.length} lagu', style: TextStyle(fontSize: 12, color: wh(.55))),
                    ]),
                  ),
                  GlassIconButton(Icons.shuffle_rounded, size: 40, tint: h.shuffle.value ? kAccent : Colors.white, onTap: h.toggleShuffle),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    h.repeat.value == RaqRepeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                    size: 40,
                    tint: h.repeat.value == RaqRepeat.off ? Colors.white : kAccent,
                    onTap: h.cycleRepeat,
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(Icons.delete_sweep_rounded, size: 40, onTap: h.clearUpcoming),
                ]),
              ),
              Expanded(
                child: q.isEmpty
                    ? Center(child: Text('Antrean kosong', style: TextStyle(color: wh(.6))))
                    : ListView(padding: const EdgeInsets.fromLTRB(8, 0, 8, 32), children: [_settings(), ..._items(q, cur)]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _settings() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Glass(
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.auto_awesome_rounded, color: kMint, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Smart Mix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text('Sisipkan lagu rekomendasi otomatis ke antrean', style: TextStyle(fontSize: 12, color: wh(.6))),
                ]),
              ),
              RaqSwitch(value: app.smartMix, onChanged: app.setSmartMix),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Transisi mulus', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text('Lagu memudar halus tanpa jeda hening', style: TextStyle(fontSize: 12, color: wh(.6))),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final s in const [0, 3, 6, 9, 12])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Pressable(
                      onTap: () => app.setCrossfade(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(50), color: app.crossfadeSec == s ? kAccent : wh(.12)),
                        child: Text(s == 0 ? 'Mati' : '$s dtk', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _items(List<Track> q, int cur) {
    final out = <Widget>[];
    Widget label(String s) => Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 6), child: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: wh(.5))));
    for (var i = 0; i < q.length; i++) {
      final t = q[i];
      if (i == cur) {
        out.add(label('Sedang diputar'));
        out.add(Glass(
          radius: 20,
          onTap: () => h.skipToQueueItem(i),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Cover(t.cover, size: 56, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kAccent)),
                  Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: wh(.65))),
                ]),
              ),
              const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.graphic_eq_rounded, color: kAccent)),
            ]),
          ),
        ));
        continue;
      }
      if (i == cur + 1) out.add(label('Berikutnya'));
      if (i == 0 && cur > 0) out.add(label('Sudah diputar'));
      final played = cur >= 0 && i < cur;
      out.add(TrackTile(
        t,
        dim: played,
        recommended: app.smartIds.contains(t.id),
        onTap: () => h.skipToQueueItem(i),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!played) Pressable(onTap: () => h.playNext(i), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.vertical_align_top_rounded, size: 22, color: wh(.6)))),
          Pressable(onTap: () => h.removeAt(i), child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close_rounded, size: 22, color: wh(.6)))),
        ]),
      ));
    }
    return out;
  }
}
