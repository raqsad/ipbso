import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/raq_audio_handler.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'player_widgets.dart';
import 'sleep_dialog.dart';

/// Pemutar layar penuh: latar cover yang di-blur, cover besar, kontrol, dan volume.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.app, required this.onQueue});
  final AppState app;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final h = app.handler;
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: Listenable.merge([app, h.shuffle, h.repeat]),
        builder: (context, _) {
          final t = app.currentTrack;
          return Stack(fit: StackFit.expand, children: [
            CoverFill(t?.cover),
            BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container(color: bk(.55))),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(children: [
                  const SizedBox(height: 8),
                  Row(children: [
                    Pressable(onTap: () => Navigator.of(context).pop(), child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.keyboard_arrow_down_rounded, size: 34, color: Colors.white))),
                    const Spacer(),
                    Text('Sedang diputar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: wh(.7))),
                    const Spacer(),
                    const SizedBox(width: 46),
                  ]),
                  const Spacer(),
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: bk(.5), blurRadius: 40, offset: const Offset(0, 20))]),
                      child: ClipRRect(borderRadius: BorderRadius.circular(28), child: CoverFill(t?.cover)),
                    ),
                  ),
                  const Spacer(),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t?.title ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text(t?.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, color: wh(.65))),
                      ]),
                    ),
                    Pressable(
                      onTap: () {
                        if (t != null) app.toggleLike(t);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          t != null && app.isLiked(t) ? Icons.star_rounded : Icons.star_border_rounded,
                          size: 30,
                          color: t != null && app.isLiked(t) ? const Color(0xFFFFD54F) : Colors.white,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  ProgressBar(handler: h),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Pressable(onTap: h.toggleShuffle, child: Icon(Icons.shuffle_rounded, size: 26, color: h.shuffle.value ? kAccent : wh(.8))),
                    Expanded(child: TransportRow(handler: h, big: 72)),
                    Pressable(
                      onTap: h.cycleRepeat,
                      child: Icon(h.repeat.value == RaqRepeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, size: 26, color: h.repeat.value == RaqRepeat.off ? wh(.8) : kAccent),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  VolumeBar(handler: h),
                  const SizedBox(height: 18),
                  Glass(
                    radius: 28,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Pressable(onTap: () => showSleepDialog(context, app), child: Icon(Icons.bedtime_rounded, size: 24, color: app.sleepEnd != null ? kMint : Colors.white)),
                        Pressable(onTap: onQueue, child: const Icon(Icons.queue_music_rounded, size: 26, color: Colors.white)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
