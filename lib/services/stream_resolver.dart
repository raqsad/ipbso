import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Alamat audio + header yang harus dikirim saat memutarnya.
class ResolvedAudio {
  const ResolvedAudio(this.url, this.headers);
  final Uri url;
  final Map<String, String> headers;
}

/// Mengubah id video YouTube jadi alamat audio yang bisa diputar. Hasilnya disimpan sementara (url kedaluwarsa).
class StreamResolver {
  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, (ResolvedAudio, DateTime)> _cache = {};

  // Klien "ios" tidak butuh dekripsi tanda tangan (tanpa Deno/JS) dan menghasilkan m4a yang cocok untuk AVPlayer.
  static const _iosUa = 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
  static const _vrUa = 'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';

  Future<ResolvedAudio> audio(String id) async {
    final hit = _cache[id];
    if (hit != null && DateTime.now().isBefore(hit.$2)) return hit.$1;
    ResolvedAudio? result;
    Object? lastError;
    for (final useIos in [true, false]) {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(
          id,
          ytClients: [useIos ? YoutubeApiClient.ios : YoutubeApiClient.androidVr],
        );
        final all = manifest.audioOnly.toList();
        if (all.isEmpty) continue;
        // AVPlayer tidak bisa memutar webm/opus, jadi utamakan m4a (mp4).
        final m4a = all.where((s) => s.container.name == 'mp4').toList();
        final pool = m4a.isNotEmpty ? m4a : all;
        pool.sort((a, b) => b.bitrate.compareTo(a.bitrate));
        result = ResolvedAudio(pool.first.url, {'User-Agent': useIos ? _iosUa : _vrUa});
        break;
      } catch (e) {
        lastError = e;
      }
    }
    if (result == null) throw lastError ?? Exception('Tidak ada stream audio untuk $id');
    _cache[id] = (result, DateTime.now().add(const Duration(minutes: 40)));
    return result;
  }
}
