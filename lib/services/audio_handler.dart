import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../models/song_item.dart';
import 'package:audio_service/audio_service.dart';

typedef VoidCallback = void Function();

class MuzicAudioHandler {
  final _player   = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  List<SongItem> _currentSongs = [];

  MuzicAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setAudioSource(_playlist);
    } catch (_) {}
  }

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

  Future<void> play()                  => _player.play();
  Future<void> pause()                 => _player.pause();
  Future<void> stop()                  => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> seekToNext()            => _player.seekToNext();
  Future<void> seekToPrevious()        => _player.seekToPrevious();

  Future<void> seekToIndex(int index) async {
    await _player.seek(Duration.zero, index: index);
  }

  Future<void> setLoopMode(LoopMode mode) => _player.setLoopMode(mode);

  // ── Playback speed (0.5x → 2.0x) ─────────────────────────────────────────
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> setShuffleModeEnabled(bool enabled) async {
    await _player.setShuffleModeEnabled(false);
  }

  Stream<bool>             get playingStream          => _player.playingStream;
  Stream<int?>             get currentIndexStream     => _player.currentIndexStream;
  Stream<ProcessingState>  get processingStateStream  => _player.processingStateStream;

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