import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_item.dart';
import '../services/audio_handler.dart';

enum RepeatMode { none, one, shuffleLoop }

class PlayerProvider extends ChangeNotifier {
  final PlayerAudioGateway _handler;

  /// Called once each time a song starts: tap, next/previous, queue
  /// auto-advance, shuffle loop restart. Play counts and "recently played"
  /// live in MusicProvider; main.dart wires the two together.
  final void Function(SongItem song)? onSongPlayed;

  PlayerProvider(this._handler, {this.onSongPlayed}) {
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

  bool _isReordering = false;
  bool _isChangingTrack = false;

  /// Id of the most recent queue-load request. A load whose id is no longer
  /// current was superseded by a newer play request and must not start
  /// playback.
  int _loadGeneration = 0;

  /// Tail of the chain that serialises engine loads, so two rapid play
  /// requests can never interleave clear()/addAll() on the audio source.
  Future<void> _loadChain = Future<void>.value();

  // ── Playback speed ─────────────────────────────────────────────────────────

  double _speed = 1.0;
  double get speed => _speed;

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _handler.setSpeed(speed);
    notifyListeners();
  }

  // ── Sleep timer ────────────────────────────────────────────────────────────

  Timer? _sleepTimer;
  Timer? _countdownTimer;
  DateTime? _sleepEndTime;

  /// null = không bật; Duration.zero = đã hết
  Duration? get sleepRemaining {
    if (_sleepEndTime == null) return null;
    final remaining = _sleepEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get sleepTimerActive => _sleepEndTime != null;

  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _countdownTimer?.cancel();
    _sleepEndTime = DateTime.now().add(duration);

    _sleepTimer = Timer(duration, () {
      unawaited(_handler.pause());
      _sleepEndTime = null;
      _sleepTimer = null;
      _countdownTimer?.cancel();
      _countdownTimer = null;
      notifyListeners();
    });

    // Tick mỗi giây để UI cập nhật countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });

    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _countdownTimer?.cancel();
    _sleepTimer = null;
    _countdownTimer = null;
    _sleepEndTime = null;
    notifyListeners();
  }

  // ── Listen to audio handler ────────────────────────────────────────────────

  late final StreamSubscription<bool> _playingSubscription;
  late final StreamSubscription<int?> _currentIndexSubscription;
  late final StreamSubscription<ProcessingState> _processingStateSubscription;

  void _listenToHandler() {
    _playingSubscription = _handler.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });

    _currentIndexSubscription = _handler.currentIndexStream.listen((index) {
      if (_isReordering || _isChangingTrack) return;

      if (index != null) _applyCurrentIndex(index);
    });

    _processingStateSubscription = _handler.processingStateStream.listen((
      state,
    ) {
      if (state == ProcessingState.completed) {
        _onPlaylistEnded();
      }
    });
  }

  Future<void> _onPlaylistEnded() async {
    if (_originalQueue.isEmpty) return;
    try {
      switch (_repeatMode) {
        case RepeatMode.one:
          return; // the engine loops the track itself
        case RepeatMode.shuffleLoop:
          _reshuffleFromRandomStart(played: true);
          if (await _loadQueueToHandler(0)) await _handler.play();
        case RepeatMode.none:
          await _rewindToQueueStart();
      }
    } catch (e) {
      debugPrint('[PlayerProvider] queue end handling failed: $e');
    }
  }

  /// New random order over the whole list; its first song becomes current.
  void _reshuffleFromRandomStart({required bool played}) {
    _buildShuffledQueueTrueRandom(
      startIndex: Random().nextInt(_originalQueue.length),
    );
    _currentPlayIndex = 0;
    _setCurrentSong(_playQueue[0], played: played);
    _historyStack.clear();
    notifyListeners();
  }

  /// Repeat off: just_audio keeps `playing == true` at `completed`, so the
  /// UI showed a pause icon and play() did nothing. Pause first (a load or
  /// seek while `playing` is true would start playback on its own), then
  /// rewind to the first song - a fresh shuffle order when shuffle is on -
  /// and wait for the user to press play.
  Future<void> _rewindToQueueStart() async {
    final generation = _loadGeneration;
    await _handler.pause();
    // A newer play request arrived while pausing; it owns the engine now.
    if (generation != _loadGeneration) return;
    if (_shuffleEnabled) {
      _reshuffleFromRandomStart(played: false);
      await _loadQueueToHandler(0);
    } else {
      await _seekToIndex(0, recordHistory: false, played: false);
      _historyStack.clear();
    }
  }

  // ── Load & Play ────────────────────────────────────────────────────────────

  Future<void> playSongs(
      List<SongItem> songs, {
        int initialIndex = 0,
        SongItem? specificSong,
      }) async {
    final loopModeDirty = _dropRepeatOne();
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

    _setCurrentSong(_playQueue[_currentPlayIndex]);
    notifyListeners();

    if (loopModeDirty) await _handler.setLoopMode(LoopMode.off);
    if (!await _loadQueueToHandler(_currentPlayIndex)) return;
    await _handler.play();
  }

  Future<void> playSongsShuffled(List<SongItem> songs) async {
    if (songs.isEmpty) return;

    final loopModeDirty = _dropRepeatOne();
    _originalQueue = List.from(songs);
    _historyStack.clear();
    _shuffleEnabled = true;

    final randomStart = Random().nextInt(songs.length);
    _buildShuffledQueueTrueRandom(startIndex: randomStart);
    _currentPlayIndex = 0;
    _setCurrentSong(_playQueue[0]);
    notifyListeners();

    if (loopModeDirty) await _handler.setLoopMode(LoopMode.off);
    if (!await _loadQueueToHandler(0)) return;
    await _handler.play();
  }

  /// Repeat-one belongs to the track that was playing; a new queue drops
  /// it. Only the flag changes here so callers can publish the new
  /// `currentSong` before their first await (screens push Now Playing
  /// right away and must not see the previous song); the returned value
  /// tells them to update the engine afterwards.
  bool _dropRepeatOne() {
    if (_repeatMode != RepeatMode.one) return false;
    _repeatMode = RepeatMode.none;
    return true;
  }

  void _buildShuffledQueueTrueRandom({required int startIndex}) {
    final rng = Random();
    final list = List<SongItem>.from(_originalQueue);
    final chosen = list.removeAt(startIndex);
    list.shuffle(rng);
    list.insert(0, chosen);
    _playQueue = list;
  }

  Future<void> enableShuffleLoop(List<SongItem> songs) async {
    if (songs.isEmpty) return;
    // Set before the first await so Now Playing, pushed immediately by
    // the caller, already shows the loop state.
    _repeatMode = RepeatMode.shuffleLoop;
    await playSongsShuffled(songs);
    await _handler.setLoopMode(LoopMode.off);
    notifyListeners();
  }

  // ── Skip ──────────────────────────────────────────────────────────────────

  Future<void> skipToNext() async {
    if (_playQueue.isEmpty) return;

    final nextIndex = _currentPlayIndex + 1;

    if (nextIndex >= _playQueue.length) return;

    await _seekToIndex(nextIndex);
    await _handler.play();
  }

  Future<void> skipToPrevious() async {
    if (_playQueue.isEmpty) return;

    if (_historyStack.isNotEmpty) {
      final prevIndex = _historyStack.last;
      await _seekToIndex(prevIndex, recordHistory: false);
      _historyStack.removeLast();
      await _handler.play();
    } else {
      await _handler.seek(Duration.zero);
    }
  }

  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= _playQueue.length) return;
    await _seekToIndex(index);
    await _handler.play();
  }

  // ── Shuffle ───────────────────────────────────────────────────────────────

  Future<void> toggleShuffle() async {
    if (_playQueue.isEmpty) {
      _shuffleEnabled = !_shuffleEnabled;
      notifyListeners();
      return;
    }

    _shuffleEnabled = !_shuffleEnabled;

    if (_shuffleEnabled) {
      final currentSongId = _currentSong?.id;
      final anchorInOriginal = currentSongId != null
          ? _originalQueue.indexWhere((s) => s.id == currentSongId)
          : 0;
      _buildShuffledQueue(
          anchorIndex: anchorInOriginal < 0 ? 0 : anchorInOriginal);
      _currentPlayIndex = 0;
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
    cancelSleepTimer();
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

  /// "Play next": [song] follows the current one instead of going last, in
  /// both the play order and the unshuffled list. With nothing playing it
  /// simply starts a queue of one, like tapping the song.
  Future<void> insertNext(SongItem song) async {
    final current = _currentSong;
    if (current == null || _playQueue.isEmpty) {
      await playSongs([song]);
      return;
    }
    final at = _currentPlayIndex + 1;
    await _handler.insertSongAt(at, song);
    _playQueue.insert(at, song);
    final originalIndex = _originalQueue.indexWhere((s) => s.id == current.id);
    if (originalIndex < 0) {
      _originalQueue.add(song);
    } else {
      _originalQueue.insert(originalIndex + 1, song);
    }
    notifyListeners();
  }

  Future<void> seekTo(Duration position) => _handler.seek(position);

  // ── Queue management ──────────────────────────────────────────────────────

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _playQueue.length) return;
    if (_isReordering) return;

    final removedId = _playQueue[index].id;
    _isReordering = true;
    try {
      await _handler.removeSongAt(index);

      _playQueue.removeAt(index);
      _originalQueue.removeWhere((s) => s.id == removedId);

      if (_playQueue.isEmpty) {
        _currentPlayIndex = 0;
        _currentSong = null;
      } else {
        if (index < _currentPlayIndex) {
          _currentPlayIndex--;
        } else if (_currentPlayIndex >= _playQueue.length) {
          _currentPlayIndex = _playQueue.length - 1;
        }
        // Removing the playing song makes the engine start the next one.
        final next = _playQueue[_currentPlayIndex];
        if (removedId == _currentSong?.id) {
          _setCurrentSong(next);
        } else {
          _currentSong = next;
        }
      }

      _historyStack.clear();
      notifyListeners();
    } finally {
      _isReordering = false;
    }
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _playQueue.length) return;
    if (newIndex < 0 || newIndex > _playQueue.length) return;
    if (oldIndex < newIndex) newIndex--;
    if (newIndex < 0 || newIndex >= _playQueue.length) return;
    if (oldIndex == newIndex || _isReordering) return;

    _isReordering = true;
    try {
      await _handler.moveSong(oldIndex, newIndex);

      final item = _playQueue.removeAt(oldIndex);
      _playQueue.insert(newIndex, item);
      if (oldIndex == _currentPlayIndex) {
        _currentPlayIndex = newIndex;
      } else if (oldIndex < _currentPlayIndex &&
          newIndex >= _currentPlayIndex) {
        _currentPlayIndex--;
      } else if (oldIndex > _currentPlayIndex &&
          newIndex <= _currentPlayIndex) {
        _currentPlayIndex++;
      }

      _currentSong = _playQueue[_currentPlayIndex];
      _historyStack.clear();
      notifyListeners();
    } finally {
      _isReordering = false;
    }
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

  /// Loads [_playQueue] into the engine starting at [startIndex].
  ///
  /// Loads run one at a time. Returns false when a newer play request
  /// superseded this one while it was queued or loading; the caller must
  /// then skip playback because the engine now holds (or will hold) the
  /// newer queue.
  Future<bool> _loadQueueToHandler(int startIndex) async {
    final generation = ++_loadGeneration;
    final previous = _loadChain;
    final completer = Completer<void>();
    _loadChain = completer.future;
    try {
      await previous;
      if (generation != _loadGeneration) return false;

      // Index events fired while the engine rebuilds its playlist refer to a
      // half-built queue; ignore them until the load has settled.
      _isChangingTrack = true;
      try {
        await _handler.loadSongs(_playQueue, initialIndex: startIndex);
      } finally {
        _isChangingTrack = false;
      }
      return generation == _loadGeneration;
    } finally {
      completer.complete();
    }
  }

  Future<void> _seekToIndex(
    int index, {
    bool recordHistory = true,
    bool played = true,
  }) async {
    _isChangingTrack = true;
    try {
      await _handler.seekToIndex(index);
      _applyCurrentIndex(index, recordHistory: recordHistory, played: played);
    } finally {
      _isChangingTrack = false;
    }
  }

  void _applyCurrentIndex(
    int index, {
    bool recordHistory = true,
    bool played = true,
  }) {
    if (index < 0 || index >= _playQueue.length) return;
    if (_playQueue[index].id == _currentSong?.id) return;

    if (recordHistory && _currentSong != null) {
      _historyStack.add(_currentPlayIndex);
    }
    _currentPlayIndex = index;
    _setCurrentSong(_playQueue[index], played: played);
    notifyListeners();
  }

  /// Makes [song] current. [played] reports it to [onSongPlayed]; the paused
  /// rewind at the end of the queue passes false because nothing starts.
  void _setCurrentSong(SongItem song, {bool played = true}) {
    _currentSong = song;
    if (played) onSongPlayed?.call(song);
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _countdownTimer?.cancel();
    _sleepTimer = null;
    _countdownTimer = null;
    _sleepEndTime = null;
    unawaited(_playingSubscription.cancel());
    unawaited(_currentIndexSubscription.cancel());
    unawaited(_processingStateSubscription.cancel());
    super.dispose();
  }
}
