import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_item.dart';
import '../services/audio_handler.dart';

// RepeatMode.one = lặp vô hạn bài hiện tại (dùng LoopMode.one của just_audio)
// enum RepeatMode { none, one }
enum RepeatMode { none, one, shuffleLoop }

class PlayerProvider extends ChangeNotifier {
  final MuzicAudioHandler _handler;

  PlayerProvider(this._handler) {
    _listenToHandler();
  }

  // ── State ──────────────────────────────────────────────────────────────────

  SongItem? _currentSong;
  SongItem? get currentSong => _currentSong;

  List<SongItem> _originalQueue = [];
  List<SongItem> _playQueue = [];

  int _currentPlayIndex = 0;

  List<SongItem> get queue => _playQueue;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  RepeatMode _repeatMode = RepeatMode.none;
  RepeatMode get repeatMode => _repeatMode;

  bool _shuffleEnabled = false;
  bool get shuffleEnabled => _shuffleEnabled;

  final List<int> _historyStack = [];

  // Flag để suppress currentIndexStream events trong khi reorder
  bool _isReordering = false;

  // ── Listen to audio handler ────────────────────────────────────────────────

  void _listenToHandler() {
    _handler.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });

    _handler.currentIndexStream.listen((index) {
      // Suppress events trong khi đang reorder (tránh state nhảy lung tung)
      if (_isReordering) return;

      if (index != null && index < _playQueue.length) {
        if (_playQueue[index].id != (_currentSong?.id ?? -1)) {
          _historyStack.add(_currentPlayIndex);
          _currentPlayIndex = index;
          _currentSong = _playQueue[index];
          notifyListeners();
        }
      }
    });

    // Chỉ xử lý khi hết playlist (RepeatMode.none)
    // RepeatMode.one được LoopMode.one của just_audio tự handle
    _handler.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onPlaylistEnded();
      }
    });
  }

  void _onPlaylistEnded() {
    if (_repeatMode == RepeatMode.shuffleLoop && _originalQueue.isNotEmpty) {
      _buildShuffledQueueTrueRandom(
        startIndex: Random().nextInt(_originalQueue.length),
      );
      _currentPlayIndex = 0;
      _currentSong = _playQueue[0];
      _loadQueueToHandler(0).then((_) => _handler.play());
      notifyListeners();
    }
  }

  // ── Load & Play ────────────────────────────────────────────────────────────

  Future<void> playSongs(
      List<SongItem> songs, {
        int initialIndex = 0,
        SongItem? specificSong,
      }) async {
    // Reset repeat khi load bài mới
    if (_repeatMode == RepeatMode.one) {
      _repeatMode = RepeatMode.none;
      await _handler.setLoopMode(LoopMode.off);
    }

    _originalQueue = List.from(songs);
    _historyStack.clear();

    int startIndex = initialIndex;
    if (specificSong != null) {
      final idx = songs.indexWhere((s) => s.id == specificSong.id);
      if (idx != -1) startIndex = idx;
    }

    if (_shuffleEnabled) {
      _buildShuffledQueue(anchorIndex: startIndex);
      _currentPlayIndex = 0;
    } else {
      _playQueue = List.from(_originalQueue);
      _currentPlayIndex = startIndex;
    }

    _currentSong = _playQueue[_currentPlayIndex];
    notifyListeners();

    await _loadQueueToHandler(_currentPlayIndex);
    await _handler.play();
  }

  Future<void> playSongsShuffled(List<SongItem> songs) async {
    if (songs.isEmpty) return;

    if (_repeatMode == RepeatMode.one) {
      _repeatMode = RepeatMode.none;
      await _handler.setLoopMode(LoopMode.off);
    }

    _originalQueue = List.from(songs);
    _historyStack.clear();
    _shuffleEnabled = true;

    // Pick random start — không cố định bài 0
    final randomStart = Random().nextInt(songs.length);
    _buildShuffledQueueTrueRandom(startIndex: randomStart);
    _currentPlayIndex = 0;
    _currentSong = _playQueue[0];
    notifyListeners();

    await _loadQueueToHandler(0);
    await _handler.play();
  }

  void _buildShuffledQueueTrueRandom({required int startIndex}) {
    final rng = Random();
    final list = List<SongItem>.from(_originalQueue);
    final chosen = list.removeAt(startIndex); // lấy bài random ra
    list.shuffle(rng);                         // shuffle toàn bộ phần còn lại
    list.insert(0, chosen);                    // đặt bài random lên đầu
    _playQueue = list;
  }

  Future<void> enableShuffleLoop(List<SongItem> songs) async {
    await playSongsShuffled(songs);
    _repeatMode = RepeatMode.shuffleLoop;
    await _handler.setLoopMode(LoopMode.off); // tự handle loop, không dùng just_audio
    notifyListeners();
  }

  // ── Skip Next / Previous ──────────────────────────────────────────────────

  Future<void> skipToNext() async {
    if (_playQueue.isEmpty) return;

    _historyStack.add(_currentPlayIndex);

    final nextIndex = _currentPlayIndex + 1;

    if (nextIndex >= _playQueue.length) {
      _historyStack.removeLast();
      return; // Hết danh sách, không loop playlist
    }

    await _handler.seekToIndex(nextIndex);
    _currentPlayIndex = nextIndex;
    _currentSong = _playQueue[_currentPlayIndex];
    await _handler.play();
    notifyListeners();
  }

  Future<void> skipToPrevious() async {
    if (_playQueue.isEmpty) return;

    if (_historyStack.isNotEmpty) {
      final prevIndex = _historyStack.removeLast();
      _currentPlayIndex = prevIndex;
      _currentSong = _playQueue[_currentPlayIndex];
      await _handler.seekToIndex(_currentPlayIndex);
      await _handler.play();
      notifyListeners();
    } else {
      await _handler.seek(Duration.zero);
    }
  }

  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= _playQueue.length) return;
    _historyStack.add(_currentPlayIndex);
    _currentPlayIndex = index;
    _currentSong = _playQueue[index];
    await _handler.seekToIndex(index);
    await _handler.play();
    notifyListeners();
  }

  // ── Shuffle ───────────────────────────────────────────────────────────────

  Future<void> toggleShuffle() async {
    if (_playQueue.isEmpty) {
      _shuffleEnabled = !_shuffleEnabled;
      notifyListeners();
      return;
    }

    _shuffleEnabled = !_shuffleEnabled;
    await _handler.setShuffleModeEnabled(false);

    if (_shuffleEnabled) {
      final currentSongId = _currentSong?.id;
      final anchorInOriginal = currentSongId != null
          ? _originalQueue.indexWhere((s) => s.id == currentSongId)
          : 0;
      _buildShuffledQueue(
          anchorIndex: anchorInOriginal < 0 ? 0 : anchorInOriginal);
      _currentPlayIndex = 0; // bài hiện tại luôn ở đầu sau khi shuffle
    } else {
      _playQueue = List.from(_originalQueue);
      final currentSongId = _currentSong?.id;
      _currentPlayIndex = currentSongId != null
          ? _originalQueue.indexWhere((s) => s.id == currentSongId)
          : 0;
      if (_currentPlayIndex < 0) _currentPlayIndex = 0;
    }

    _historyStack.clear();
    _currentSong = _playQueue[_currentPlayIndex];

    // ── Reorder in-place bằng move() — KHÔNG dừng audio ──────────────────
    _isReordering = true;
    try {
      await _handler.reorderTo(_playQueue);
    } finally {
      _isReordering = false;
    }

    notifyListeners();
  }

  // ── Repeat ────────────────────────────────────────────────────────────────

  Future<void> toggleRepeat() async {
    switch (_repeatMode) {
      case RepeatMode.none:
        _repeatMode = RepeatMode.one;
        await _handler.setLoopMode(LoopMode.one);
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.none;
        await _handler.setLoopMode(LoopMode.off);
        break;
      case RepeatMode.shuffleLoop:
        _repeatMode = RepeatMode.none;
        await _handler.setLoopMode(LoopMode.off);
        break;
    }
    notifyListeners();
  }

  // ── Playback controls ─────────────────────────────────────────────────────

  Future<void> playPause() async {
    if (_isPlaying) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  Future<void> stopAndClear() async {
    await _handler.stop();
    _currentSong = null;
    _playQueue = [];
    _originalQueue = [];
    _historyStack.clear();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> addToQueue(SongItem song) async {
    _originalQueue.add(song);
    _playQueue.add(song);
    await _handler.addSongToQueue(song);
    notifyListeners();
  }

  Future<void> seekTo(Duration position) => _handler.seek(position);

  // ── Queue management ──────────────────────────────────────────────────────

  void removeFromQueue(int index) {
    if (index < 0 || index >= _playQueue.length) return;
    final removedId = _playQueue[index].id;
    _playQueue.removeAt(index);
    _originalQueue.removeWhere((s) => s.id == removedId);
    if (index < _currentPlayIndex) _currentPlayIndex--;
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final item = _playQueue.removeAt(oldIndex);
    _playQueue.insert(newIndex, item);
    if (oldIndex == _currentPlayIndex) {
      _currentPlayIndex = newIndex;
    } else if (oldIndex < _currentPlayIndex && newIndex >= _currentPlayIndex) {
      _currentPlayIndex--;
    } else if (oldIndex > _currentPlayIndex && newIndex <= _currentPlayIndex) {
      _currentPlayIndex++;
    }
    notifyListeners();
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<PositionData> get positionDataStream => _handler.positionDataStream;
  Stream<bool> get playingStream => _handler.playingStream;
  Stream<ProcessingState> get processingStateStream =>
      _handler.processingStateStream;

  // ── Private helpers ───────────────────────────────────────────────────────

  void _buildShuffledQueue({required int anchorIndex}) {
    final rng = Random();
    final list = List<SongItem>.from(_originalQueue);

    if (anchorIndex > 0 && anchorIndex < list.length) {
      final anchor = list.removeAt(anchorIndex);
      list.insert(0, anchor);
    }

    for (int i = list.length - 1; i > 1; i--) {
      final j = rng.nextInt(i - 1) + 1;
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }

    _playQueue = list;
  }

  Future<void> _loadQueueToHandler(int startIndex) async {
    await _handler.loadSongs(_playQueue, initialIndex: startIndex);
  }
}