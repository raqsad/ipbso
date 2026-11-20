import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../core/models.dart';
import 'stream_resolver.dart';

enum RaqRepeat { off, all, one }

/// Pemutar utama. Mengelola antrean sendiri (alamat audio baru diambil saat lagu dimulai),
/// dan terhubung ke kontrol layar kunci / Control Center lewat audio_service.
class RaqAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player = AudioPlayer();
  final StreamResolver _resolver = StreamResolver();

  final ValueNotifier<List<Track>> queueTracks = ValueNotifier<List<Track>>(<Track>[]);
  final ValueNotifier<int> currentIndex = ValueNotifier<int>(-1);
  final ValueNotifier<bool> shuffle = ValueNotifier<bool>(false);
  final ValueNotifier<RaqRepeat> repeat = ValueNotifier<RaqRepeat>(RaqRepeat.off);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  /// Dipanggil saat antrean hampir habis; mengembalikan lagu tambahan (autoplay).
  Future<List<Track>> Function(Track seed)? onNeedMore;

  /// Durasi fade antar lagu (detik); 0 = mati.
  int fadeSec = 0;

  int _loadToken = 0;
  int _fails = 0;
  bool _loadingMore = false;
  bool _faded = false;
  Timer? _fadeTimer;

  RaqAudioHandler() {
    player.playbackEventStream.listen((_) => _broadcast(), onError: (Object e, StackTrace s) {});
    player.playingStream.listen((_) => _broadcast());
    player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) _onCompleted();
    });
    player.durationStream.listen((d) {
      final m = mediaItem.value;
      if (d != null && m != null && m.duration != d) mediaItem.add(m.copyWith(duration: d));
    });
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 120), (_) => _fadeTick());
  }

  List<Track> get tracks => queueTracks.value;
  Track? get current {
    final i = currentIndex.value;
    return i >= 0 && i < tracks.length ? tracks[i] : null;
  }

  // ------------------------------------------------------------------------------------------ memutar
  Future<void> playQueue(List<Track> list, int start) async {
    if (list.isEmpty) return;
    queueTracks.value = List<Track>.of(list);
    _fails = 0;
    await _playIndex(start.clamp(0, list.length - 1).toInt());
  }

  Future<void> _playIndex(int i) async {
    final list = tracks;
    if (i < 0 || i >= list.length) return;
    final token = ++_loadToken;
    currentIndex.value = i;
    final t = list[i];
    mediaItem.add(MediaItem(
      id: t.id,
      title: t.title,
      artist: t.artist,
      artUri: t.cover != null ? Uri.parse(t.cover!) : null,
      duration: t.durationSec != null ? Duration(seconds: t.durationSec!) : null,
    ));
    _broadcast();
    try {
      final r = await _resolver.audio(t.id);
      if (token != _loadToken) return;
      await player.setAudioSource(AudioSource.uri(r.url, headers: r.headers));
      if (token != _loadToken) return;
      _fails = 0;
      error.value = null;
      unawaited(player.play());
      unawaited(_maybeLoadMore());
    } catch (e) {
      if (token != _loadToken) return;
      error.value = 'Gagal memutar "${t.title}"';
      _fails++;
      if (_fails > 3) {
        await player.pause();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (token == _loadToken) await skipToNext();
    }
  }

  Future<void> _maybeLoadMore({bool force = false}) async {
    final cb = onNeedMore;
    final cur = current;
    if (cb == null || cur == null || _loadingMore) return;
    final upcoming = tracks.length - currentIndex.value - 1;
    if (!force && upcoming > 2) return;
    _loadingMore = true;
    try {
      final more = await cb(cur);
      final have = tracks.map((t) => t.id).toSet();
      final fresh = more.where((t) => !have.contains(t.id)).take(10).toList();
      if (fresh.isNotEmpty) queueTracks.value = [...tracks, ...fresh];
    } catch (_) {
      // abaikan: antrean tetap seperti semula
    } finally {
      _loadingMore = false;
    }
  }

  void _onCompleted() {
    if (repeat.value == RaqRepeat.one) {
      unawaited(player.seek(Duration.zero).then((_) => player.play()));
    } else {
      unawaited(skipToNext());
    }
  }

  // ------------------------------------------------------------------------------------------ kontrol (juga dipakai layar kunci)
  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    final i = currentIndex.value;
    if (tracks.isEmpty) return;
    if (i + 1 < tracks.length) return _playIndex(i + 1);
    if (repeat.value == RaqRepeat.all) return _playIndex(0);
    await _maybeLoadMore(force: true);
    if (i + 1 < tracks.length) return _playIndex(i + 1);
    await player.pause();
  }

  @override
  Future<void> skipToPrevious() async {
    if (tracks.isEmpty) return;
    if (player.position > const Duration(seconds: 3)) return player.seek(Duration.zero);
    final i = currentIndex.value;
    return _playIndex(i > 0 ? i - 1 : 0);
  }

  @override
  Future<void> skipToQueueItem(int index) => _playIndex(index);

  Future<void> togglePlay() => player.playing ? player.pause() : player.play();

  // ------------------------------------------------------------------------------------------ antrean
  void removeAt(int i) {
    final list = List<Track>.of(tracks);
    final cur = currentIndex.value;
    if (i < 0 || i >= list.length || i == cur) return;
    list.removeAt(i);
    queueTracks.value = list;
    if (i < cur) currentIndex.value = cur - 1;
  }

  void playNext(int i) {
    final list = List<Track>.of(tracks);
    final cur = currentIndex.value;
    if (i < 0 || i >= list.length || i == cur) return;
    final t = list.removeAt(i);
    final newCur = i < cur ? cur - 1 : cur;
    list.insert(newCur + 1, t);
    queueTracks.value = list;
    currentIndex.value = newCur;
  }

  void clearUpcoming() {
    final cur = currentIndex.value;
    if (cur < 0 || cur + 1 >= tracks.length) return;
    queueTracks.value = tracks.sublist(0, cur + 1);
  }

  void addToQueueEnd(Track t) {
    if (tracks.any((x) => x.id == t.id)) return;
    queueTracks.value = [...tracks, t];
  }

  /// Smart Mix: sisipkan rekomendasi dengan pola 2 lagu kamu, 1 rekomendasi.
  void insertSmart(List<Track> fresh) {
    final list = List<Track>.of(tracks);
    final cur = currentIndex.value;
    for (var k = 0; k < fresh.length; k++) {
      final at = math.min(cur + 3 + k * 3, list.length);
      list.insert(at, fresh[k]);
    }
    queueTracks.value = list;
  }

  void toggleShuffle() {
    shuffle.value = !shuffle.value;
    if (!shuffle.value) return;
    final cur = currentIndex.value;
    final head = tracks.sublist(0, math.min(cur + 1, tracks.length));
    final rest = tracks.sublist(head.length)..shuffle();
    queueTracks.value = [...head, ...rest];
  }

  void cycleRepeat() {
    repeat.value = RaqRepeat.values[(repeat.value.index + 1) % RaqRepeat.values.length];
  }

  // ------------------------------------------------------------------------------------------ fade & status
  void _fadeTick() {
    if (fadeSec <= 0) {
      if (_faded) {
        player.setVolume(1.0);
        _faded = false;
      }
      return;
    }
    if (!player.playing) return;
    final dur = player.duration;
    if (dur == null || dur.inMilliseconds <= 0) return;
    final d = dur.inMilliseconds.toDouble();
    final pos = player.position.inMilliseconds.toDouble();
    final fadeMs = math.min(fadeSec * 1000.0, d / 4);
    if (fadeMs <= 0) return;
    var f = math.min(pos / fadeMs, (d - pos) / fadeMs);
    if (f > 1.0) f = 1.0;
    if (f < 0.0) f = 0.0;
    player.setVolume(math.sqrt(f)); // kurva daya-sama: terdengar rata
    _faded = true;
  }

  void _broadcast() {
    final playing = player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: currentIndex.value < 0 ? null : currentIndex.value,
    ));
  }

  void dispose() {
    _fadeTimer?.cancel();
    player.dispose();
  }
}
