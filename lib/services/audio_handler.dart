import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../models/song_item.dart';
import 'package:audio_service/audio_service.dart';

typedef VoidCallback = void Function();

abstract class PlayerAudioGateway {
  Future<void> loadSongs(List<SongItem> songs, {int initialIndex = 0});
  Future<void> reorderTo(List<SongItem> newOrder);
  Future<void> moveSong(int oldIndex, int newIndex);
  Future<void> removeSongAt(int index);
  Future<void> addSongToQueue(SongItem song);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> seekToIndex(int index);
  Future<void> setLoopMode(LoopMode mode);
  Future<void> setSpeed(double speed);
  Future<void> setShuffleModeEnabled(bool enabled);

  Stream<bool> get playingStream;
  Stream<int?> get currentIndexStream;
  Stream<ProcessingState> get processingStateStream;
  Stream<PositionData> get positionDataStream;
}

class MuzicAudioHandler implements PlayerAudioGateway {
  final _player   = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  List<SongItem> _currentSongs = [];

  MuzicAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setAudioSource(_playlist);
    } catch (e, st) {
      debugPrint('[AudioHandler] setAudioSource failed: $e\n$st');
    }
  }

  @override
  Future<void> loadSongs(List<SongItem> songs, {int initialIndex = 0}) async {
    _currentSongs = List.from(songs);
    await _playlist.clear();
    await _playlist.addAll(
      songs.map((s) => AudioSource.uri(
        Uri.file(s.data),
        tag: MediaItem(
          id: s.id.toString(),
          title: s.title,
          artist: s.artist,
          album: s.album,
          duration: Duration(milliseconds: s.duration),
          artUri: Uri.parse(
            'content://media/external/audio/albumart/${s.albumId}',
          ),
        ),
      )).toList(),
    );
    await _player.seek(Duration.zero, index: initialIndex);
  }

  /// Reorder ConcatenatingAudioSource to match [newOrder] using move() operations.
  /// Does NOT interrupt currently playing audio — no clear/rebuild.
  @override
  Future<void> reorderTo(List<SongItem> newOrder) async {
    if (newOrder.length != _currentSongs.length) return;

    final tracking = List<SongItem>.from(_currentSongs);

    for (int targetIdx = 0; targetIdx < newOrder.length; targetIdx++) {
      final targetSong = newOrder[targetIdx];
      final currentIdx = tracking.indexWhere((s) => s.id == targetSong.id);

      if (currentIdx < 0 || currentIdx == targetIdx) continue;

      await _playlist.move(currentIdx, targetIdx);

      final song = tracking.removeAt(currentIdx);
      tracking.insert(targetIdx, song);
    }

    _currentSongs = List.from(newOrder);
  }

  @override
  Future<void> moveSong(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _currentSongs.length) return;
    if (newIndex < 0 || newIndex >= _currentSongs.length) return;
    if (oldIndex == newIndex) return;

    await _playlist.move(oldIndex, newIndex);
    final song = _currentSongs.removeAt(oldIndex);
    _currentSongs.insert(newIndex, song);
  }

  @override
  Future<void> removeSongAt(int index) async {
    if (index < 0 || index >= _currentSongs.length) return;

    await _playlist.removeAt(index);
    _currentSongs.removeAt(index);
  }

  @override
  Future<void> addSongToQueue(SongItem song) async {
    _currentSongs.add(song);
    await _playlist.add(AudioSource.uri(
      Uri.file(song.data),
      tag: MediaItem(
        id: song.id.toString(),
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: Duration(milliseconds: song.duration),
        artUri: Uri.parse(
          'content://media/external/audio/albumart/${song.albumId}',
        ),
      ),
    ));
  }

  @override
  Future<void> play()                  => _player.play();
  @override
  Future<void> pause()                 => _player.pause();
  @override
  Future<void> stop()                  => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> seekToNext()            => _player.seekToNext();
  Future<void> seekToPrevious()        => _player.seekToPrevious();

  @override
  Future<void> seekToIndex(int index) async {
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> setLoopMode(LoopMode mode) => _player.setLoopMode(mode);

  // ── Playback speed (0.5x → 2.0x) ─────────────────────────────────────────
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {
    await _player.setShuffleModeEnabled(false);
  }

  @override
  Stream<bool>             get playingStream          => _player.playingStream;
  @override
  Stream<int?>             get currentIndexStream     => _player.currentIndexStream;
  @override
  Stream<ProcessingState>  get processingStateStream  => _player.processingStateStream;

  @override
  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
            (pos, buf, dur) => PositionData(pos, buf, dur ?? Duration.zero),
      );

  bool           get playing            => _player.playing;
  LoopMode       get loopMode           => _player.loopMode;
  bool           get shuffleModeEnabled => _player.shuffleModeEnabled;
  int?           get currentIndex       => _player.currentIndex;
  List<SongItem> get currentSongs       => _currentSongs;
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  const PositionData(this.position, this.bufferedPosition, this.duration);
}
