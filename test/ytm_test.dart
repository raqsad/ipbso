import 'dart:convert';
import '../lib/core/models.dart';
import '../lib/core/ytm_parse.dart';

void check(bool ok, String msg) { print((ok ? 'OK   ' : 'GAGAL') + ' $msg'); if (!ok) throw Exception(msg); }

void main() {
  // hasil pencarian (responsive list item)
  final search = jsonDecode('''
  {"contents":{"tabbedSearchResultsRenderer":{"tabs":[{"tabRenderer":{"content":{"sectionListRenderer":{"contents":[{"musicShelfRenderer":{"title":{"runs":[{"text":"Lagu"}]},"contents":[
   {"musicResponsiveListItemRenderer":{"playlistItemData":{"videoId":"VID1"},
     "thumbnail":{"musicThumbnailRenderer":{"thumbnail":{"thumbnails":[{"url":"https://lh3.googleusercontent.com/abc=w60-h60-l90-rj"},{"url":"https://lh3.googleusercontent.com/abc=w226-h226-l90-rj"}]}}},
     "flexColumns":[{"musicResponsiveListItemFlexColumnRenderer":{"text":{"runs":[{"text":"the cure"}]}}},
      {"musicResponsiveListItemFlexColumnRenderer":{"text":{"runs":[{"text":"Lagu"},{"text":" • "},{"text":"Olivia Rodrigo"},{"text":" • "},{"text":"GUTS"},{"text":" • "},{"text":"4:56"}]}}}]}},
   {"musicResponsiveListItemRenderer":{"overlay":{"x":{"watchEndpoint":{"videoId":"VID2"}}},
     "flexColumns":[{"musicResponsiveListItemFlexColumnRenderer":{"text":{"runs":[{"text":"Walk Away"}]}}},
      {"musicResponsiveListItemFlexColumnRenderer":{"text":{"runs":[{"text":"Song"},{"text":" • "},{"text":"OLIVIA"},{"text":" • "},{"text":"3:07"}]}}}]}}
  ]}}]}}}}]}}}
  ''');
  final t = parseTracks(search);
  check(t.length == 2, 'search: 2 lagu (${t.length})');
  check(t[0].id == 'VID1' && t[0].title == 'the cure' && t[0].artist == 'Olivia Rodrigo', 'search: judul & artis (${t[0].artist})');
  check(t[0].durationSec == 296, 'search: durasi 4:56 = 296 (${t[0].durationSec})');
  check(t[0].cover!.endsWith('=w544-h544'), 'search: cover dibesarkan (${t[0].cover})');
  check(t[1].id == 'VID2' && t[1].artist == 'OLIVIA' && t[1].durationSec == 187, 'search: lagu 2 via overlay.watchEndpoint');

  // home: carousel + two-row
  Map two(String id, String title, String artist) => {
        'musicTwoRowItemRenderer': {
          'navigationEndpoint': {'watchEndpoint': {'videoId': id}},
          'title': {'runs': [{'text': title}]},
          'subtitle': {'runs': [{'text': 'Lagu'}, {'text': ' • '}, {'text': artist}]},
          'thumbnailRenderer': {'musicThumbnailRenderer': {'thumbnail': {'thumbnails': [{'url': 'https://i.ytimg.com/vi/$id/hq.jpg'}]}}}
        }
      };
  final home = {
    'contents': {'sectionListRenderer': {'contents': [
      {'musicCarouselShelfRenderer': {'header': {'musicCarouselShelfBasicHeaderRenderer': {'title': {'runs': [{'text': 'Quick picks'}]}}},
        'contents': [two('a1', 'A', 'X'), two('a2', 'B', 'Y'), two('a3', 'C', 'Z'),
          {'musicTwoRowItemRenderer': {'navigationEndpoint': {'browseEndpoint': {'browseId': 'MPRE'}}, 'title': {'runs': [{'text': 'Album'}]}}}]}},
      {'musicCarouselShelfRenderer': {'header': {'musicCarouselShelfBasicHeaderRenderer': {'title': {'runs': [{'text': 'Terlalu sedikit'}]}}}, 'contents': [two('b1', 'A', 'X')]}},
    ]}}
  };
  final shelves = parseShelves(home);
  check(shelves.length == 1, 'home: 1 rak (yang <3 lagu dibuang) (${shelves.length})');
  check(shelves[0].title == 'Quick picks' && shelves[0].tracks.length == 3, 'home: judul rak & 3 lagu, album dilewati');
  check(shelves[0].tracks[0].artist == 'X' && shelves[0].tracks[0].cover!.contains('ytimg'), 'home: artis & cover ytimg tidak diubah');

  // next / radio
  final next = {'contents': {'x': [{'playlistPanelVideoRenderer': {'videoId': 'R1', 'title': {'runs': [{'text': 'Rec 1'}]},
      'longBylineText': {'runs': [{'text': 'Artis'}, {'text': ' • '}, {'text': 'Album'}, {'text': ' • '}, {'text': '2024'}]},
      'lengthText': {'runs': [{'text': '3:10'}]}, 'thumbnail': {'thumbnails': [{'url': 'https://i.ytimg.com/a.jpg'}]}}}]}};
  final r = parseTracks(next);
  check(r.length == 1 && r[0].artist == 'Artis' && r[0].durationSec == 190, 'next: playlistPanelVideoRenderer');
  check(parseTracks({}).isEmpty && parseShelves([]).isEmpty, 'kosong aman');
  check(fmtTime(const Duration(seconds: 187)) == '3:07' && fmtTime(const Duration(seconds: 3729)) == '1:02:09', 'fmtTime');
  final j = Track.fromJson(t[0].toJson());
  check(j == t[0] && j.durationSec == 296, 'Track toJson/fromJson');
}
