import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_item.dart';
import '../services/audio_handler.dart';

// Chỉ còn 2 mode: none và all
enum RepeatMode { none, all }

class PlayerProvider extends ChangeNotifier {
  final MuzicAudioHandler _handler;

  PlayerProvider(this._handler) {
    _listenToHandler();
  }

  // ── State ──────────────────────────────────────────────────────────────────

  SongItem? _currentSong;
  SongItem? get currentSong => _currentSong;

  /// _originalQueue: thứ tự gốc user chọn, không bao giờ thay đổi sau khi load
  List<SongItem> _originalQueue = [];

  /// _playQueue: thứ tự đang thực sự phát (= original khi shuffle OFF,
  ///             = shuffled list khi shuffle ON)
  List<SongItem> _playQueue = [];

  /// _currentPlayIndex: vị trí hiện tại trong _playQueue
  int _currentPlayIndex = 0;

  /// queue exposed ra UI (Queue Sheet dùng cái này)
  List<SongItem> get queue => _playQueue;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  RepeatMode _repeatMode = RepeatMode.none;
  RepeatMode get repeatMode => _repeatMode;

  bool _shuffleEnabled = false;
  bool get shuffleEnabled => _shuffleEnabled;

  /// History stack cho Previous — lưu index trong _playQueue
  final List<int> _historyStack = [];

  // ── Listen to audio handler ────────────────────────────────────────────────

  void _listenToHandler() {
    _handler.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });

    // Handler báo track đổi (tự next bởi just_audio) → sync state
    _handler.currentIndexStream.listen((index) {
      // just_audio sẽ chỉ tự advance khi LoopMode.off/all với sequential playlist
      // Ta dùng LoopMode.off + single-item hoặc sequential tuỳ mode
      // Khi just_audio tự chuyển track → sync _currentSong
      if (index != null && index < _playQueue.length) {
        if (_playQueue[index].id != (_currentSong?.id ?? -1)) {
          _historyStack.add(_currentPlayIndex);
          _currentPlayIndex = index;
          _currentSong = _playQueue[index];
          notifyListeners();
        }
      }
    });

    // Khi playlist kết thúc (processingState == completed)
    _handler.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onPlaylistEnded();
      }
    });
  }

  void _onPlaylistEnded() {
    if (_repeatMode == RepeatMode.all) {
      // Loop: nếu shuffle ON → re-shuffle rồi play lại từ đầu
      if (_shuffleEnabled) {
        _rebuildShuffledQueue(keepCurrentFirst: false);
      }
      _handler.seekToIndex(0);
      _handler.play();
      _currentPlayIndex = 0;
      _currentSong = _playQueue.isNotEmpty ? _playQueue[0] : null;
      notifyListeners();
    }
    // RepeatMode.none → dừng, handler tự stop
  }

  // ── Load & Play ────────────────────────────────────────────────────────────

  Future<void> playSongs(
      List<SongItem> songs, {
        int initialIndex = 0,
        SongItem? specificSong,
      }) async {
    _originalQueue = List.from(songs);
    _historyStack.clear();

    int startIndex = initialIndex;
    if (specificSong != null) {
      final idx = songs.indexWhere((s) => s.id == specificSong.id);
      if (idx != -1) startIndex = idx;
    }

    if (_shuffleEnabled) {
      // Shuffle nhưng đặt bài được chọn lên đầu
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

  // ── Skip Next / Previous ──────────────────────────────────────────────────

  Future<void> skipToNext() async {
    if (_playQueue.isEmpty) return;

    _historyStack.add(_currentPlayIndex);

    final nextIndex = _currentPlayIndex + 1;

    if (nextIndex >= _playQueue.length) {
      // Cuối danh sách
      if (_repeatMode == RepeatMode.all) {
        if (_shuffleEnabled) {
          _rebuildShuffledQueue(keepCurrentFirst: false);
        }
        await _handler.seekToIndex(0);
        _currentPlayIndex = 0;
      } else {
        // Không loop → không làm gì
        _historyStack.removeLast();
        return;
      }
    } else {
      await _handler.seekToIndex(nextIndex);
      _currentPlayIndex = nextIndex;
    }

    _currentSong = _playQueue[_currentPlayIndex];
    await _handler.play();
    notifyListeners();
  }

  Future<void> skipToPrevious() async {
    if (_playQueue.isEmpty) return;

    // Nếu đang phát > 3 giây → restart bài hiện tại
    // (hành vi chuẩn như Spotify)
    // Không có position access trực tiếp nên dùng seekToIndex cùng index
    if (_historyStack.isNotEmpty) {
      final prevIndex = _historyStack.removeLast();
      _currentPlayIndex = prevIndex;
      _currentSong = _playQueue[_currentPlayIndex];
      await _handler.seekToIndex(_currentPlayIndex);
      await _handler.play();
      notifyListeners();
    } else {
      // Không có history → quay lại đầu bài
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
    _shuffleEnabled = !_shuffleEnabled;

    // Tắt shuffle native của just_audio — ta tự quản lý
    await _handler.setShuffleModeEnabled(false);

    if (_shuffleEnabled) {
      // Bật shuffle: shuffle _originalQueue, giữ bài hiện tại ở đầu
      final currentSongId = _currentSong?.id;
      final anchorInOriginal = currentSongId != null
          ? _originalQueue.indexWhere((s) => s.id == currentSongId)
          : 0;
      _buildShuffledQueue(anchorIndex: anchorInOriginal < 0 ? 0 : anchorInOriginal);
      _currentPlayIndex = 0; // bài hiện tại luôn ở vị trí 0 sau khi shuffle
    } else {
      // Tắt shuffle: quay về _originalQueue, tìm lại vị trí bài hiện tại
      _playQueue = List.from(_originalQueue);
      final currentSongId = _currentSong?.id;
      _currentPlayIndex = currentSongId != null
          ? _originalQueue.indexWhere((s) => s.id == currentSongId)
          : 0;
      if (_currentPlayIndex < 0) _currentPlayIndex = 0;
    }

    _historyStack.clear();
    _currentSong = _playQueue[_currentPlayIndex];

    await _loadQueueToHandler(_currentPlayIndex);
    await _handler.play();
    notifyListeners();
  }

  // ── Repeat ────────────────────────────────────────────────────────────────

  Future<void> toggleRepeat() async {
    switch (_repeatMode) {
      case RepeatMode.none:
        _repeatMode = RepeatMode.all;
        // just_audio loop off — ta tự handle end-of-playlist
        await _handler.setLoopMode(LoopMode.off);
        break;
      case RepeatMode.all:
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
  Stream<ProcessingState> get processingStateStream => _handler.processingStateStream;

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Fisher-Yates shuffle, đặt bài tại [anchorIndex] lên đầu
  void _buildShuffledQueue({required int anchorIndex}) {
    final rng = Random();
    final list = List<SongItem>.from(_originalQueue);

    // Đặt anchor lên đầu
    if (anchorIndex > 0 && anchorIndex < list.length) {
      final anchor = list.removeAt(anchorIndex);
      list.insert(0, anchor);
    }

    // Shuffle phần còn lại (index 1 trở đi)
    for (int i = list.length - 1; i > 1; i--) {
      final j = rng.nextInt(i - 1) + 1; // chỉ shuffle từ index 1
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }

    _playQueue = list;
  }

  /// Tạo lại shuffled queue mới (cho loop all) — không giữ anchor
  void _rebuildShuffledQueue({bool keepCurrentFirst = false}) {
    final rng = Random();
    final list = List<SongItem>.from(_originalQueue);

    if (keepCurrentFirst && _currentSong != null) {
      final idx = list.indexWhere((s) => s.id == _currentSong!.id);
      if (idx > 0) {
        final anchor = list.removeAt(idx);
        list.insert(0, anchor);
      }
      for (int i = list.length - 1; i > 1; i--) {
        final j = rng.nextInt(i - 1) + 1;
        final tmp = list[i];
        list[i] = list[j];
        list[j] = tmp;
      }
    } else {
      // Full shuffle không giữ anchor
      for (int i = list.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final tmp = list[i];
        list[i] = list[j];
        list[j] = tmp;
      }
    }

    _playQueue = list;
  }

  /// Load toàn bộ _playQueue vào just_audio handler, seek đến [startIndex]
  Future<void> _loadQueueToHandler(int startIndex) async {
    await _handler.loadSongs(_playQueue, initialIndex: startIndex);
  }
}