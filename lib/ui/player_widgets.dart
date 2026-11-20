import 'package:flutter/material.dart';

import '../core/models.dart';
import '../services/raq_audio_handler.dart';
import 'common.dart';

/// Progress lagu: garis tipis + waktu berjalan (kiri) dan sisa waktu (kanan).
class ProgressBar extends StatefulWidget {
  const ProgressBar({super.key, required this.handler});
  final RaqAudioHandler handler;

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final player = widget.handler.player;
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      initialData: player.duration,
      builder: (context, ds) {
        final dur = ds.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          initialData: player.position,
          builder: (context, ps) {
            final pos = ps.data ?? Duration.zero;
            final frac = dur.inMilliseconds <= 0 ? 0.0 : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0).toDouble();
            final shown = _drag ?? frac;
            final shownMs = (shown * dur.inMilliseconds).round();
            final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: wh(.6));
            return Column(children: [
              SlimBar(
                value: shown,
                onChanged: (v) => setState(() => _drag = v),
                onEnd: (v) {
                  player.seek(Duration(milliseconds: (v * dur.inMilliseconds).round()));
                  setState(() => _drag = null);
                },
              ),
              Row(children: [
                Text(fmtTime(Duration(milliseconds: shownMs)), style: style),
                const Spacer(),
                Text('-${fmtTime(dur - Duration(milliseconds: shownMs))}', style: style),
              ]),
            ]);
          },
        );
      },
    );
  }
}

/// Volume pemutar (relatif terhadap volume sistem; tombol fisik tetap mengatur volume sistem).
class VolumeBar extends StatefulWidget {
  const VolumeBar({super.key, required this.handler});
  final RaqAudioHandler handler;

  @override
  State<VolumeBar> createState() => _VolumeBarState();
}

class _VolumeBarState extends State<VolumeBar> {
  late double _v = widget.handler.player.volume;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(Icons.volume_mute_rounded, size: 18, color: wh(.6)),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SlimBar(
            value: _v,
            activeAlpha: .6,
            onChanged: (v) {
              setState(() => _v = v);
              widget.handler.player.setVolume(v);
            },
          ),
        ),
      ),
      Icon(Icons.volume_up_rounded, size: 18, color: wh(.6)),
    ]);
  }
}

/// Tombol transport: mundur, play/pause (besar), maju.
class TransportRow extends StatelessWidget {
  const TransportRow({super.key, required this.handler, this.big = 64});
  final RaqAudioHandler handler;
  final double big;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      Pressable(onTap: handler.skipToPrevious, child: const Icon(Icons.fast_rewind_rounded, size: 46, color: Colors.white)),
      StreamBuilder<bool>(
        stream: handler.player.playingStream,
        initialData: handler.player.playing,
        builder: (context, s) => Pressable(
          onTap: handler.togglePlay,
          child: Icon((s.data ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded, size: big, color: Colors.white),
        ),
      ),
      Pressable(onTap: handler.skipToNext, child: const Icon(Icons.fast_forward_rounded, size: 46, color: Colors.white)),
    ]);
  }
}
