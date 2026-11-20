import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'common.dart';

const _telegramUrl = 'https://t.me/raqkdp';
const _whatsappUrl = 'https://whatsapp.com/channel/0029VbDSpCr3GJOyeFoZ0004';

/// "About" ala kartu kaca: video kecil yang berputar, info singkat, dan tautan saluran Telegram & WhatsApp.
Future<void> showAboutCard(BuildContext context) => showBlurCard<void>(context, (c) => const _AboutCard());

class _AboutCard extends StatefulWidget {
  const _AboutCard();

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  late final VideoPlayerController _video;

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.asset('assets/about.mp4');
    _video.initialize().then((_) async {
      await _video.setLooping(true);
      await _video.setVolume(0);
      await _video.play();
      if (mounted) setState(() {});
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return CardShell(
      maxWidth: 380,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              const ColoredBox(color: Color(0xFF1C1C1E)),
              if (_video.value.isInitialized) FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: 640, height: 360, child: VideoPlayer(_video))),
              DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, bk(.35)]))),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Berst', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
        Text('by Raq', style: TextStyle(fontSize: 14, color: wh(.6))),
        const SizedBox(height: 10),
        Text(
          'Pemutar musik dengan tampilan kaca, antrean pintar, dan pemindah playlist dari Spotify dan aplikasi lain.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.35, color: wh(.75)),
        ),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerLeft, child: Text('Gabung komunitas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: wh(.5)))),
        const SizedBox(height: 8),
        _LinkRow(icon: Icons.send_rounded, brand: const Color(0xFF29A9EB), title: 'Saluran Info Telegram', sub: 't.me/raqkdp', onTap: () => _open(_telegramUrl)),
        const SizedBox(height: 8),
        _LinkRow(icon: Icons.chat_rounded, brand: const Color(0xFF25D366), title: 'Saluran WhatsApp', sub: 'Info & update terbaru', onTap: () => _open(_whatsappUrl)),
        const SizedBox(height: 14),
        Pressable(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: wh(.14), borderRadius: BorderRadius.circular(50)),
            alignment: Alignment.center,
            child: const Text('Tutup', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.brand, required this.title, required this.sub, required this.onTap});
  final IconData icon;
  final Color brand;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: wh(.08), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: brand, shape: BoxShape.circle), child: Icon(icon, size: 20, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              Text(sub, style: TextStyle(fontSize: 12, color: wh(.6))),
            ]),
          ),
          Icon(Icons.open_in_new_rounded, size: 18, color: wh(.55)),
        ]),
      ),
    );
  }
}
