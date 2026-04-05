import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_item.dart';
import '../services/audio_handler.dart';

enum RepeatMode { none, all, one }

class PlayerProvider extends ChangeNotifier {
  final MuzicAudioHandler _handler;

  PlayerProvider(this._handler) {
    _listenToHandler();
    _handler.onRepeatOneDone = _handleRepeatOneDone;
  }

  SongItem? _currentSong;
  SongItem? get currentSong => _currentSong;

  List<SongItem> _queue = [];
  List<SongItem> get queue => _queue;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  RepeatMode _repeatMode = RepeatMode.none;
  RepeatMode get repeatMode => _repeatMode;

  bool _shuffleEnabled = false;
  bool get shuffleEnabled => _shuffleEnabled;

  bool _repeatOneHandled = false;

  void _listenToHandler() {
    _handler.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });

    _handler.currentIndexStream.listen((index) {
      if (index != null && _queue.isNotEmpty && index < _queue.length) {
        _currentSong = _queue[index];
        _repeatOneHandled = false;
        notifyListeners();
      }
    });
  }

  void _handleRepeatOneDone() {
    if (_repeatMode == RepeatMode.one && !_repeatOneHandled) {
      _repeatOneHandled = true;
      _repeatMode = RepeatMode.none;
      _handler.setLoopMode(LoopMode.off);
      notifyListeners();
    }
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  Future<void> playSongs(
      List<SongItem> songs, {
        int initialIndex = 0,
        SongItem? specificSong,
      }) async {
    _queue = List.from(songs);

    int startIndex = initialIndex;
    if (specificSong != null) {
      final idx = songs.indexWhere((s) => s.id == specificSong.id);
      if (idx != -1) startIndex = idx;
    }

    _currentSong = _queue[startIndex];
    _repeatOneHandled = false;
    notifyListeners();

    await _handler.loadSongs(songs, initialIndex: startIndex);
    await _handler.play();
  }

  Future<void> playPause() async {
    if (_isPlaying) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  /// Dừng phát nhạc hoàn toàn và xóa trạng thái hiện tại.
  /// Dùng cho nút × trên mini player.
  Future<void> stopAndClear() async {
    await _handler.stop();
    _currentSong = null;
    _queue = [];
    _isPlaying = false;
    notifyListeners();
  }

  /// Thêm một bài vào cuối hàng chờ (không interrupt bài đang phát).
  Future<void> addToQueue(SongItem song) async {
    _queue.add(song);
    await _handler.addSongToQueue(song);
    notifyListeners();
  }

  Future<void> skipToNext()              => _handler.seekToNext();
  Future<void> skipToPrevious()          => _handler.seekToPrevious();
  Future<void> seekTo(Duration position) => _handler.seek(position);
  Future<void> skipToIndex(int index)    => _handler.seekToIndex(index);

  // ── Repeat ────────────────────────────────────────────────────────────────

  Future<void> toggleRepeat() async {
    switch (_repeatMode) {
      case RepeatMode.none:
        _repeatMode = RepeatMode.all;
        await _handler.setLoopMode(LoopMode.all);
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        await _handler.setLoopMode(LoopMode.one);
        _repeatOneHandled = false;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.none;
        await _handler.setLoopMode(LoopMode.off);
        break;
    }
    notifyListeners();
  }

  // ── Shuffle ───────────────────────────────────────────────────────────────

  Future<void> toggleShuffle() async {
    _shuffleEnabled = !_shuffleEnabled;
    await _handler.setShuffleModeEnabled(_shuffleEnabled);
    if (!_shuffleEnabled && _repeatMode == RepeatMode.none) {
      await _handler.setLoopMode(LoopMode.off);
    }
    notifyListeners();
  }

  // ── Queue management ──────────────────────────────────────────────────────

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    notifyListeners();
  }

  Stream<PositionData> get positionDataStream => _handler.positionDataStream;
  Stream<bool>         get playingStream       => _handler.playingStream;
}