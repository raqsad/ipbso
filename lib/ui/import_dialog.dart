import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../services/importer.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Import playlist: tempel link Spotify / Deezer / YouTube Music, atau pilih file CSV / JSON / M3U / TXT.
Future<void> showImportCard(BuildContext context, AppState app, {required void Function(PlaylistData) onOpen}) {
  app.importer.reset(); // bersihkan hasil lama, tapi jangan ganggu import yang sedang berjalan
  return showBlurCard<void>(context, (c) => _ImportCard(app: app, onOpen: (p) {
        Navigator.of(c).pop();
        onOpen(p);
      }));
}

class _ImportCard extends StatefulWidget {
  const _ImportCard({required this.app, required this.onOpen});
  final AppState app;
  final void Function(PlaylistData) onOpen;

  @override
  State<_ImportCard> createState() => _ImportCardState();
}

class _ImportCardState extends State<_ImportCard> {
  final TextEditingController _link = TextEditingController();

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final bytes = f.bytes;
    if (bytes == null || bytes.length > 8000000) {
      if (mounted) toast(context, 'File tidak bisa dibaca (maks. 8 MB)');
      return;
    }
    final dot = f.name.lastIndexOf('.');
    final name = (dot > 0 ? f.name.substring(0, dot) : f.name).trim();
    widget.app.importer.fromText(name.isEmpty ? 'Playlist import' : name, utf8.decode(bytes, allowMalformed: true));
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => _link.text = d!.text!);
  }

  @override
  Widget build(BuildContext context) {
    final imp = widget.app.importer;
    return CardShell(
      maxWidth: 400,
      child: ValueListenableBuilder<ImportState>(
        valueListenable: imp.state,
        builder: (context, st, _) {
          switch (st.phase) {
            case ImportPhase.idle:
              return _idle(imp);
            case ImportPhase.reading:
            case ImportPhase.matching:
              return _progress(imp, st);
            case ImportPhase.done:
              return _done(st);
            case ImportPhase.error:
              return _error(imp, st);
          }
        },
      ),
    );
  }

  Widget _primary(String text, VoidCallback? onTap) => Pressable(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(color: onTap == null ? wh(.25) : Colors.white, borderRadius: BorderRadius.circular(50)),
          alignment: Alignment.center,
          child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black)),
        ),
      );

  Widget _ghost(String text, VoidCallback onTap, {IconData? icon}) => Pressable(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(color: wh(.14), borderRadius: BorderRadius.circular(50)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: Colors.white), const SizedBox(width: 8)],
            Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
        ),
      );

  Widget _idle(PlaylistImporter imp) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_download_rounded, size: 34, color: kMint),
      const SizedBox(height: 8),
      const Text('Import Playlist', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
      Text('Pindahkan playlist dari Spotify atau aplikasi lain', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: wh(.65))),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.only(left: 14, right: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: wh(.3))),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _link,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: kMint,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(border: InputBorder.none, hintText: 'Tempel link Spotify / Deezer / YouTube Music', hintStyle: TextStyle(fontSize: 13, color: wh(.45))),
            ),
          ),
          Pressable(onTap: _paste, child: const Padding(padding: EdgeInsets.all(10), child: Text('Tempel', style: TextStyle(color: kMint, fontSize: 13, fontWeight: FontWeight.w600)))),
        ]),
      ),
      const SizedBox(height: 12),
      _primary('Import dari link', _link.text.trim().isEmpty ? null : () => imp.fromUrl(_link.text)),
      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('atau', style: TextStyle(fontSize: 12, color: wh(.5)))),
      _ghost('Pilih file (CSV, JSON, M3U, TXT)', _pickFile, icon: Icons.folder_open_rounded),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: wh(.07), borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tips', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            '\u2022 Spotify: link playlist publik (maks. sekitar 100 lagu). Lebih dari itu atau privat: ekspor ke CSV lewat exportify.net, lalu pilih filenya.\n'
            '\u2022 Apple Music, Tidal, Amazon, dan lainnya: ekspor ke file lewat tunemymusic.com atau soundiiz.com, lalu pilih filenya.\n'
            '\u2022 Link YouTube Music langsung memindahkan semua lagunya tanpa pencarian.\n'
            '\u2022 Lagu dicocokkan ke YouTube Music, jadi sebagian kecil bisa tidak ketemu.',
            style: TextStyle(fontSize: 12, height: 1.4, color: wh(.65)),
          ),
        ]),
      ),
    ]);
  }

  Widget _progress(PlaylistImporter imp, ImportState st) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(st.name.isEmpty ? 'Mengimpor...' : st.name, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 18),
      ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: LinearProgressIndicator(
          value: st.total > 0 ? (st.done / st.total).clamp(0.0, 1.0).toDouble() : null,
          minHeight: 8,
          color: kMint,
          backgroundColor: wh(.2),
        ),
      ),
      const SizedBox(height: 10),
      Text(st.total > 0 ? '${st.done} / ${st.total} lagu' : (st.done > 0 ? '${st.done} lagu terbaca' : st.message), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
      const SizedBox(height: 8),
      Text('Boleh ditutup, proses jalan terus di latar belakang.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: wh(.5))),
      const SizedBox(height: 18),
      _ghost('Batal', imp.cancel),
    ]);
  }

  Widget _done(ImportState st) {
    final miss = (st.total - st.matched).clamp(0, 1 << 30);
    final pl = widget.app.playlists.where((p) => p.id == st.playlistId).firstOrNull;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle_rounded, size: 46, color: kMint),
      const SizedBox(height: 10),
      const Text('Selesai!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 4),
      Text(st.message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: wh(.8))),
      const SizedBox(height: 6),
      Text('${st.matched} dari ${st.total} lagu berhasil dipindahkan${miss > 0 ? ' ($miss tidak ditemukan)' : ''}', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: wh(.6))),
      const SizedBox(height: 18),
      _primary('Buka playlist', pl == null ? null : () => widget.onOpen(pl)),
      const SizedBox(height: 10),
      _ghost('Tutup', () => Navigator.of(context).pop()),
    ]);
  }

  Widget _error(PlaylistImporter imp, ImportState st) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, size: 42, color: kAccent),
      const SizedBox(height: 10),
      const Text('Gagal mengimpor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 6),
      Text(st.message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: wh(.75))),
      const SizedBox(height: 18),
      _primary('Coba lagi', imp.reset),
      const SizedBox(height: 10),
      _ghost('Tutup', () => Navigator.of(context).pop()),
    ]);
  }
}
