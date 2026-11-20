/// Model data dasar (Dart murni, tanpa Flutter) supaya mudah diuji.

class Track {
  final String id;
  final String title;
  final String artist;
  final String? cover;
  final int? durationSec;

  const Track({required this.id, required this.title, required this.artist, this.cover, this.durationSec});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'artist': artist, 'cover': cover, 'dur': durationSec};

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '-',
        artist: (j['artist'] as String?) ?? '',
        cover: j['cover'] as String?,
        durationSec: j['dur'] as int?,
      );

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Shelf {
  final String title;
  final List<Track> tracks;
  const Shelf(this.title, this.tracks);
}

class PlaylistData {
  final String id;
  String name;
  final List<Track> tracks;

  PlaylistData({required this.id, required this.name, List<Track>? tracks}) : tracks = tracks ?? [];

  String? get cover => tracks.isEmpty ? null : tracks.first.cover;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'tracks': tracks.map((t) => t.toJson()).toList()};

  factory PlaylistData.fromJson(Map<String, dynamic> j) => PlaylistData(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Playlist',
        tracks: ((j['tracks'] as List?) ?? const []).map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

/// 3:07 atau 1:02:09.
String fmtTime(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}
