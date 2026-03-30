import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../models/song_item.dart';

typedef VoidCallback = void Function();

class MuzicAudioHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  List<SongItem> _currentSongs = [];

  VoidCallback? onRepeatOneDone;

  MuzicAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setAudioSource(_playlist);
    } catch (_) {}

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        onRepeatOneDone?.call();
      }
    });
  }

  Future<void> loadSongs(List<SongItem> songs, {int initialIndex = 0}) async {
    _currentSongs = songs;
    await _playlist.clear();
    await _playlist.addAll(
      songs.map((s) => AudioSource.file(s.data)).toList(),
    );
    await _player.seek(Duration.zero, index: initialIndex);
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> seekToNext() => _player.seekToNext();
  Future<void> seekToPrevious() => _player.seekToPrevious();

  Future<void> seekToIndex(int index) async {
    await _player.seek(Duration.zero, index: index);
    await _player.play();
  }

  Future<void> setLoopMode(LoopMode mode) => _player.setLoopMode(mode);

  Future<void> setShuffleModeEnabled(bool enabled) async {
    await _player.setShuffleModeEnabled(enabled);
    // Shuffle must pair with LoopMode.all or playlist stops after last song
    if (enabled && _player.loopMode == LoopMode.off) {
      await _player.setLoopMode(LoopMode.all);
    }
  }

  Stream<bool> get playingStream => _player.playingStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (pos, buf, dur) => PositionData(pos, buf, dur ?? Duration.zero),
      );

  bool get playing => _player.playing;
  LoopMode get loopMode => _player.loopMode;
  bool get shuffleModeEnabled => _player.shuffleModeEnabled;
  int? get currentIndex => _player.currentIndex;
  List<SongItem> get currentSongs => _currentSongs;
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  const PositionData(this.position, this.bufferedPosition, this.duration);
}
