import '../lib/core/import_parse.dart';

void check(bool ok, String msg) { print((ok ? 'OK   ' : 'GAGAL') + ' $msg'); if (!ok) throw Exception(msg); }

void main() {
  var l = ImportParsers.parseText('Exportify', '\uFEFF"Track URI","Track Name","Album Name","Artist Name(s)","Release Date"\n"spotify:track:1","the cure","GUTS (spilled)","Olivia Rodrigo","2024"\n"spotify:track:2","Hello, World","Alb","A;B","2020"\r\n"spotify:track:3","Say ""Hi""","Alb","C","2020"');
  check(l.length == 1 && l[0].tracks.length == 3, 'exportify: 3 lagu');
  check(l[0].tracks[0].title == 'the cure' && l[0].tracks[0].artist == 'Olivia Rodrigo', 'exportify: judul & artis');
  check(l[0].tracks[1].title == 'Hello, World' && l[0].tracks[1].artist == 'A B', 'exportify: koma dalam tanda kutip, ; jadi spasi');
  check(l[0].tracks[2].title == 'Say "Hi"', 'exportify: kutip ganda ("")');

  l = ImportParsers.parseText('S', 'Title;Artist;Album\nHoneybee;Olivia Rodrigo;GUTS\nDrop Dead;Olivia Rodrigo;GUTS');
  check(l[0].tracks.length == 2 && l[0].tracks[1].title == 'Drop Dead' && l[0].tracks[1].artist == 'Olivia Rodrigo', 'soundiiz: pemisah titik koma');

  l = ImportParsers.parseText('N', 'Walk Away,OLIVIA\nPurple,Olivia Rodrigo');
  check(l[0].tracks.length == 2 && l[0].tracks[0].title == 'Walk Away' && l[0].tracks[0].artist == 'OLIVIA', 'tanpa header: kolom 1 judul, kolom 2 artis');

  l = ImportParsers.parseText('J', '[{"title":"Song A","artist":"X"},{"name":"Song B","artists":["Y","Z"]},"Plain C"]');
  check(l[0].tracks.length == 3 && l[0].tracks[1].artist == 'Y Z' && l[0].tracks[2].title == 'Plain C' && l[0].tracks[2].artist.isEmpty, 'json: array campuran');

  l = ImportParsers.parseText('P', '{"playlists":[{"name":"Favorit","items":[{"track":{"trackName":"Dangerously Easy","artistName":"Olivia Dean","albumName":"x"},"episode":null},{"track":{"trackName":"my way","artistName":"Olivia Rodrigo"}}]},{"name":"Santai","items":[{"track":{"trackName":"Purple","artistName":"Olivia Rodrigo"}}]}]}');
  check(l.length == 2 && l[0].name == 'Favorit' && l[0].tracks.length == 2 && l[1].tracks[0].title == 'Purple', 'ekspor Spotify: 2 playlist');

  l = ImportParsers.parseText('L', '{"tracks":[{"artist":"A","album":"B","track":"T1","uri":"u"},{"artist":"C","album":"D","track":"T2"}]}');
  check(l.length == 1 && l[0].tracks.length == 2 && l[0].tracks[0].title == 'T1' && l[0].tracks[0].artist == 'A', 'YourLibrary.json');

  l = ImportParsers.parseText('M', '#EXTM3U\n#EXTINF:210,Olivia Rodrigo - the cure\n/storage/a.mp3\n#EXTINF:180,Walk Away - OLIVIA\n/storage/b.mp3');
  check(l[0].tracks.length == 2 && l[0].tracks[0].title == 'Olivia Rodrigo - the cure', 'm3u');

  l = ImportParsers.parseText('Tx', '1. Olivia Rodrigo - drop dead\n2) Antoon - Olivia\n\n# komentar\nJohn Mayer - Something Like Olivia');
  check(l[0].tracks.length == 3 && l[0].tracks[0].title == 'Olivia Rodrigo - drop dead' && l[0].tracks[1].title == 'Antoon - Olivia', 'teks bebas (nomor dibuang, komentar dilewati)');
  check(ImportParsers.parseText('x', '   ').isEmpty, 'teks kosong');

  const html = '<html><head><title>Playlist - Santai | Spotify</title></head><body><script id="__NEXT_DATA__" type="application/json">{"props":{"pageProps":{"state":{"data":{"entity":{"type":"playlist","name":"Santai Sore","title":"Santai Sore","trackList":[{"uri":"spotify:track:a","title":"Dangerously Easy","subtitle":"Olivia Dean","duration":200000},{"uri":"spotify:track:b","title":"the cure","subtitle":"Olivia Rodrigo","duration":1}]}}}}}}</script></body></html>';
  var s = ImportParsers.spotifyEmbed(html);
  check(s != null && s.name == 'Santai Sore' && s.tracks.length == 2 && s.tracks[1].artist == 'Olivia Rodrigo', 'spotify embed (__NEXT_DATA__)');
  const html2 = r'<html><title>Lagu Galau | Spotify</title><script>{"foo":[{"title":"Judul \u0026 Satu","subtitle":"Artis\u00a0Satu"},{"title":"Dua","subtitle":"B"}]}</script></html>';
  s = ImportParsers.spotifyEmbed(html2);
  check(s != null && s.name == 'Lagu Galau' && s.tracks.length == 2 && s.tracks[0].title == 'Judul & Satu' && s.tracks[0].artist == 'Artis Satu', 'spotify embed (cadangan regex, unescape)');
  check(ImportParsers.spotifyEmbed('<html>kosong</html>') == null, 'spotify embed kosong = null');

  check(ImportParsers.spotifyRef('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=abc')!.$2 == '37i9dQZF1DXcBWIGoYBM5M', 'spotify link playlist');
  check(ImportParsers.spotifyRef('spotify:album:4aawyAB9vmqN3uQ7FjRGTy')!.$1 == 'album', 'spotify uri album');
  check(ImportParsers.deezerPlaylistId('https://www.deezer.com/en/playlist/1313621735') == '1313621735', 'deezer id');
  check(ImportParsers.youtubeListId('https://music.youtube.com/playlist?list=PLabc_123-x&si=1') == 'PLabc_123-x', 'youtube list id');
  check(ImportParsers.kindOf('https://link.deezer.com/s/abc') == LinkKind.deezer && ImportParsers.kindOf('https://youtu.be/x?list=PL1') == LinkKind.youtube && ImportParsers.kindOf('https://tidal.com/x') == LinkKind.unknown, 'kindOf');

  final c = [const Cand('the cure (Live)', 'Olivia Rodrigo', 'live'), const Cand('The Cure', 'The Cure', 'band'), const Cand('the cure', 'Olivia Rodrigo', 'studio')];
  check(ImportParsers.pick(c, const ImportedTrack('the cure', 'Olivia Rodrigo'))?.ref == 'studio', 'pencocokan: pilih studio, bukan live / band lain');
  check(ImportParsers.pick([const Cand('Totally Other', 'Someone')], const ImportedTrack('the cure', 'Olivia Rodrigo')) == null, 'pencocokan: tidak mirip = null');
  check(ImportParsers.pick([const Cand('drop dead', 'Olivia Rodrigo', 1)], const ImportedTrack('Olivia Rodrigo - drop dead'))?.ref == 1, 'pencocokan: baris bebas');
  check(ImportParsers.pick([const Cand('Honey', 'Other', 1), const Cand('honeybee', 'Olivia Rodrigo', 2)], const ImportedTrack('honeybee (feat. X)', 'Olivia Rodrigo'))?.ref == 2, 'pencocokan: abaikan (feat. X)');
}
