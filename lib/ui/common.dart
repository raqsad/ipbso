import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';

const kAccent = Color(0xFFFA2D48);
const kMint = Color(0xFF2DE2C0);
const kViolet = Color(0xFF7C3AED);

Color wh(double o) => Color.fromRGBO(255, 255, 255, o);
Color bk(double o) => Color.fromRGBO(0, 0, 0, o);

ThemeData buildTheme() => ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(primary: kAccent, secondary: kMint),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );

void toast(BuildContext context, String msg) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Text(msg),
    duration: const Duration(seconds: 2),
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF2C2C2E),
  ));
}

/// Tombol/area yang mengecil sedikit saat ditekan (rasa iPhone) + getar halus.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.96, this.haptic = true});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Liquid Glass: blur nyata di belakang, dasar gelap tipis, kilau diagonal, dan tepi bercahaya.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 22, this.padding, this.onTap, this.blur = 18, this.tint});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double blur;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [wh(.70), wh(.10), wh(.04), wh(.38)],
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: (tint ?? Colors.black).withAlpha(41),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [wh(.22), wh(.07)]),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
    return onTap == null ? box : Pressable(onTap: onTap, child: box);
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton(this.icon, {super.key, required this.onTap, this.size = 46, this.tint = Colors.white, this.dot = false});
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color tint;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Glass(
        radius: size / 2,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(alignment: Alignment.center, children: [
            Icon(icon, color: tint, size: size * 0.5),
            if (dot)
              Positioned(
                top: size * 0.2,
                right: size * 0.2,
                child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: kMint, shape: BoxShape.circle)),
              ),
          ]),
        ),
      ),
    );
  }
}

class Cover extends StatelessWidget {
  const Cover(this.url, {super.key, this.size = 52, this.radius = 12});
  final String? url;
  final double size;
  final double radius;

  Widget _placeholder() => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A3A3C), Color(0xFF1C1C1E)]),
        ),
        child: Center(child: Icon(Icons.music_note_rounded, color: wh(.4), size: size * 0.4)),
      );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? _placeholder()
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                memCacheWidth: (size * 3).round(),
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (c, u) => _placeholder(),
                errorWidget: (c, u, e) => _placeholder(),
              ),
      ),
    );
  }
}

/// Cover yang mengisi ruang yang tersedia (untuk kartu besar / latar).
class CoverFill extends StatelessWidget {
  const CoverFill(this.url, {super.key});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null) return const ColoredBox(color: Color(0xFF1C1C1E));
    return CachedNetworkImage(
      imageUrl: u,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      placeholder: (c, _) => const ColoredBox(color: Color(0xFF1C1C1E)),
      errorWidget: (c, _, e) => const ColoredBox(color: Color(0xFF1C1C1E)),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class TrackTile extends StatelessWidget {
  const TrackTile(this.track, {super.key, this.rank, this.playing = false, this.onTap, this.trailing, this.recommended = false, this.dim = false});
  final Track track;
  final int? rank;
  final bool playing;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool recommended;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Opacity(
        opacity: dim ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(children: [
            if (rank != null)
              SizedBox(
                width: 28,
                child: Text('$rank', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: rank! <= 3 ? kAccent : wh(.55))),
              ),
            Cover(track.cover, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                const SizedBox(height: 2),
                Row(children: [
                  if (recommended) ...[
                    const Icon(Icons.auto_awesome_rounded, size: 12, color: kMint),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      recommended ? 'Rekomendasi \u00B7 ${track.artist}' : track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: recommended ? kMint : wh(.65)),
                    ),
                  ),
                ]),
              ]),
            ),
            if (playing) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.graphic_eq_rounded, color: kMint)),
            trailing ?? Icon(Icons.play_arrow_rounded, color: wh(.7)),
          ]),
        ),
      ),
    );
  }
}

/// Garis tipis ala Apple Music: tanpa bulatan, menebal saat disentuh. Dipakai untuk progress & volume.
class SlimBar extends StatefulWidget {
  const SlimBar({super.key, required this.value, required this.onChanged, this.onEnd, this.activeAlpha = .9});
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onEnd;
  final double activeAlpha;

  @override
  State<SlimBar> createState() => _SlimBarState();
}

class _SlimBarState extends State<SlimBar> {
  bool _dragging = false;
  double _last = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      double frac(double dx) => w <= 0 ? 0.0 : (dx / w).clamp(0.0, 1.0).toDouble();
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final f = frac(d.localPosition.dx);
          widget.onChanged(f);
          widget.onEnd?.call(f);
        },
        onHorizontalDragStart: (d) {
          setState(() => _dragging = true);
          _last = frac(d.localPosition.dx);
          widget.onChanged(_last);
        },
        onHorizontalDragUpdate: (d) {
          _last = frac(d.localPosition.dx);
          widget.onChanged(_last);
        },
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onEnd?.call(_last);
        },
        child: SizedBox(
          height: 28,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              height: _dragging ? 11 : 6,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: wh(.28)),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: widget.value.clamp(0.0, 1.0).toDouble(),
                child: Container(color: wh(widget.activeAlpha)),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Saklar ala iPhone.
class RaqSwitch extends StatelessWidget {
  const RaqSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 52,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: value ? kMint : wh(.2)),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(width: 26, height: 26, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
      ),
    );
  }
}

/// Kartu kaca di tengah layar dengan latar yang di-blur (nyata) dan digelapkan. Tap di luar = tutup.
Future<T?> showBlurCard<T>(BuildContext context, WidgetBuilder builder) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (c, a, b) => builder(c),
    transitionBuilder: (c, anim, secondary, child) {
      final t = Curves.easeOutCubic.transform(anim.value);
      return Stack(children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22 * t, sigmaY: 22 * t),
            child: Container(color: bk(.38 * t)),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => Navigator.of(c).pop(), child: const SizedBox.expand()),
        ),
        Center(
          child: Transform.scale(
            scale: 0.92 + 0.08 * t,
            child: Opacity(opacity: t, child: GestureDetector(onTap: () {}, child: child)),
          ),
        ),
      ]);
    },
  );
}

/// Bungkus isi kartu: lebar maksimal, kaca, dan bisa di-scroll kalau layar pendek.
class CardShell extends StatelessWidget {
  const CardShell({super.key, required this.child, this.maxWidth = 400, this.radius = 32});
  final Widget child;
  final double maxWidth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: h * 0.86),
          child: Glass(
            radius: radius,
            tint: const Color(0xFF48484A),
            blur: 24,
            child: SingleChildScrollView(padding: const EdgeInsets.all(18), child: child),
          ),
        ),
      ),
    );
  }
}
