import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_item.dart';
import '../services/audio_handler.dart';

enum RepeatMode { none, all, one }

class PlayerProvider extends ChangeNotifier {
  final MuzicAudioHandler _handler;

  PlayerProvider(this._handler) {
    _listenToHandler();
    // When RepeatOne song finishes once → auto reset to none
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

  // Track whether we already handled the one-repeat completion
  bool _repeatOneHandled = false;

  void _listenToHandler() {
    _handler.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });

    _handler.currentIndexStream.listen((index) {
      if (index != null && _queue.isNotEmpty && index < _queue.length) {
        _currentSong = _queue[index];
        // New song started: reset the one-repeat guard
        _repeatOneHandled = false;
        notifyListeners();
      }
    });
  }

  /// Called by audio_handler when processingState == completed
  void _handleRepeatOneDone() {
    if (_repeatMode == RepeatMode.one && !_repeatOneHandled) {
      _repeatOneHandled = true;
      // Turn off repeat, let natural playback end
      _repeatMode = RepeatMode.none;
      _handler.setLoopMode(LoopMode.off);
      notifyListeners();
    }
  }

  // ── Playback ───────────────────────────────────────────

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

  Future<void> skipToNext() => _handler.seekToNext();
  Future<void> skipToPrevious() => _handler.seekToPrevious();
  Future<void> seekTo(Duration position) => _handler.seek(position);
  Future<void> skipToIndex(int index) => _handler.seekToIndex(index);

  // ── Repeat: none → all → one → none ───────────────────
  Future<void> toggleRepeat() async {
    switch (_repeatMode) {
      case RepeatMode.none:
        _repeatMode = RepeatMode.all;
        await _handler.setLoopMode(LoopMode.all);
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        // LoopMode.one in just_audio = repeat same track continuously
        // We intercept completion via onRepeatOneDone to reset after 1 extra play
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

  // ── Shuffle ────────────────────────────────────────────
  Future<void> toggleShuffle() async {
    _shuffleEnabled = !_shuffleEnabled;
    await _handler.setShuffleModeEnabled(_shuffleEnabled);
    // If turning off shuffle, restore loop to none (unless user set repeat)
    if (!_shuffleEnabled && _repeatMode == RepeatMode.none) {
      await _handler.setLoopMode(LoopMode.off);
    }
    notifyListeners();
  }

  // ── Queue ──────────────────────────────────────────────
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
  Stream<bool> get playingStream => _handler.playingStream;
}
