import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muziczz/models/song_item.dart';
import 'package:muziczz/providers/player_provider.dart';
import 'package:muziczz/services/audio_handler.dart';

void main() {
  late _FakePlayerAudioGateway gateway;
  late PlayerProvider provider;

  setUp(() {
    gateway = _FakePlayerAudioGateway();
    provider = PlayerProvider(gateway);
  });

  tearDown(() async {
    provider.dispose();
    await gateway.dispose();
  });

  test(
    'removing a queued song keeps provider and audio engine aligned',
    () async {
      final songs = [_song(1), _song(2), _song(3)];
      await provider.playSongs(songs);

      await provider.removeFromQueue(1);

      expect(provider.queue.map((song) => song.id), [1, 3]);
      expect(gateway.queue.map((song) => song.id), [1, 3]);

      await provider.skipToIndex(1);
      expect(provider.currentSong?.id, 3);
      expect(gateway.currentSong?.id, 3);
    },
  );

  test('reordering queue keeps provider and audio engine aligned', () async {
    final songs = [_song(1), _song(2), _song(3)];
    await provider.playSongs(songs);

    await provider.reorderQueue(2, 0);

    expect(provider.queue.map((song) => song.id), [3, 1, 2]);
    expect(gateway.queue.map((song) => song.id), [3, 1, 2]);

    await provider.skipToIndex(0);
    expect(provider.currentSong?.id, 3);
    expect(gateway.currentSong?.id, 3);
  });

  test('failed engine removal leaves provider queue unchanged', () async {
    final songs = [_song(1), _song(2), _song(3)];
    await provider.playSongs(songs);
    gateway.failRemove = true;

    await expectLater(provider.removeFromQueue(1), throwsStateError);

    expect(provider.queue.map((song) => song.id), [1, 2, 3]);
    expect(provider.currentSong?.id, 1);
  });

  test('failed engine move leaves provider queue unchanged', () async {
    final songs = [_song(1), _song(2), _song(3)];
    await provider.playSongs(songs);
    gateway.failMove = true;

    await expectLater(provider.reorderQueue(2, 0), throwsStateError);

    expect(provider.queue.map((song) => song.id), [1, 2, 3]);
    expect(provider.currentSong?.id, 1);
  });

  test(
    'removing the current song advances both queues to the next song',
    () async {
      final songs = [_song(1), _song(2), _song(3)];
      await provider.playSongs(songs, initialIndex: 1);

      await provider.removeFromQueue(1);

      expect(provider.queue.map((song) => song.id), [1, 3]);
      expect(provider.currentSong?.id, 3);
      expect(gateway.currentSong?.id, 3);
    },
  );

  test('moving the current song preserves it in provider and engine', () async {
    final songs = [_song(1), _song(2), _song(3)];
    await provider.playSongs(songs, initialIndex: 1);

    await provider.reorderQueue(1, 3);

    expect(provider.queue.map((song) => song.id), [1, 3, 2]);
    expect(provider.currentSong?.id, 2);
    expect(gateway.currentSong?.id, 2);
  });

  testWidgets('resetting sleep timer keeps a single countdown ticker', (
    tester,
  ) async {
    var notifications = 0;
    provider.addListener(() => notifications++);

    provider.setSleepTimer(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    provider.setSleepTimer(const Duration(minutes: 2));
    notifications = 0;

    await tester.pump(const Duration(seconds: 1));

    expect(notifications, 1);
    provider.cancelSleepTimer();
  });

  test('disposing provider cancels every audio stream subscription', () async {
    final ownedGateway = _FakePlayerAudioGateway();
    final ownedProvider = PlayerProvider(ownedGateway);

    ownedProvider.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(ownedGateway.cancelledSubscriptions, 3);
    await ownedGateway.dispose();
  });

  test(
    'manual next records one history entry regardless of stream timing',
    () async {
      gateway.emitIndexOnSeek = true;
      await provider.playSongs([_song(1), _song(2), _song(3)]);

      await provider.skipToNext();
      await provider.skipToPrevious();
      await provider.skipToPrevious();

      expect(gateway.seekToIndexCalls, [1, 0]);
      expect(gateway.seekCalls, [Duration.zero]);
    },
  );

  test('automatic index changes record each track transition once', () async {
    await provider.playSongs([_song(1), _song(2), _song(3)]);

    gateway.emitCurrentIndex(1);
    gateway.emitCurrentIndex(1);
    await provider.skipToPrevious();
    await provider.skipToPrevious();

    expect(gateway.seekToIndexCalls, [0]);
    expect(gateway.seekCalls, [Duration.zero]);
  });

  test('a play request issued mid-load waits, then replaces the queue', () async {
    gateway.blockLoads = true;

    final first = provider.playSongs([_song(1), _song(2)]);
    await _settle();
    expect(gateway.pendingLoads, hasLength(1));

    final second = provider.playSongs([_song(3), _song(4)]);
    await _settle();
    // The second request must wait instead of racing the in-flight load.
    expect(gateway.pendingLoads, hasLength(1));

    gateway.pendingLoads.removeAt(0).complete();
    await _settle();
    expect(gateway.pendingLoads, hasLength(1));
    // The superseded request must not start playback of its stale queue.
    expect(gateway.playCalls, 0);

    gateway.pendingLoads.removeAt(0).complete();
    await Future.wait([first, second]);

    expect(gateway.queue.map((song) => song.id), [3, 4]);
    expect(provider.queue.map((song) => song.id), [3, 4]);
    expect(provider.currentSong?.id, 3);
    expect(gateway.currentSong?.id, 3);
    expect(gateway.playCalls, 1);
  });

  test('near-simultaneous play requests never interleave engine loads', () async {
    gateway.blockLoads = true;

    final first = provider.playSongs([_song(1), _song(2)]);
    final second = provider.playSongs([_song(3), _song(4)]);
    await _settle();

    // Release loads one by one; at no point may two be in flight.
    while (gateway.pendingLoads.isNotEmpty) {
      expect(gateway.pendingLoads, hasLength(1));
      gateway.pendingLoads.removeAt(0).complete();
      await _settle();
    }
    await Future.wait([first, second]);

    expect(gateway.queue.map((song) => song.id), [3, 4]);
    expect(provider.queue.map((song) => song.id), [3, 4]);
    expect(provider.currentSong?.id, 3);
    expect(gateway.currentSong?.id, 3);
    expect(gateway.playCalls, 1);
  });

  test('index events emitted while loading do not change the song', () async {
    gateway.blockLoads = true;

    final play = provider.playSongs(
      [_song(1), _song(2), _song(3)],
      initialIndex: 2,
    );
    await _settle();
    expect(provider.currentSong?.id, 3);

    // The engine reports index 0 after addAll(), before the initial seek.
    gateway.emitCurrentIndex(0);
    await _settle();
    expect(provider.currentSong?.id, 3);

    gateway.pendingLoads.removeAt(0).complete();
    await play;
    expect(provider.currentSong?.id, 3);

    // History must still be empty: previous restarts the track instead of
    // seeking back to the phantom index 0.
    await provider.skipToPrevious();
    expect(gateway.seekToIndexCalls, isEmpty);
    expect(gateway.seekCalls, [Duration.zero]);
  });

  test('play requests publish the new song before their first await', () async {
    await provider.playSongs([_song(1)]);
    await provider.toggleRepeat();
    expect(provider.repeatMode, RepeatMode.one);

    final play = provider.playSongs([_song(2), _song(3)]);
    expect(provider.currentSong?.id, 2);
    expect(provider.repeatMode, RepeatMode.none);
    await play;

    await provider.toggleRepeat();
    final shuffled = provider.playSongsShuffled([_song(4), _song(5)]);
    expect(provider.currentSong?.id, anyOf(4, 5));
    expect(provider.repeatMode, RepeatMode.none);
    await shuffled;

    final loop = provider.enableShuffleLoop([_song(6), _song(7)]);
    expect(provider.currentSong?.id, anyOf(6, 7));
    expect(provider.repeatMode, RepeatMode.shuffleLoop);
    await loop;
  });

  test('shuffle loop on an empty list is a no-op', () async {
    await provider.enableShuffleLoop(const []);

    expect(provider.repeatMode, RepeatMode.none);
    expect(provider.currentSong, isNull);
    expect(gateway.log, isEmpty);
  });

  group('queue end with repeat off', () {
    test('pauses first, then rewinds to the first song without playing', () async {
      await provider.playSongs([_song(1), _song(2), _song(3)], initialIndex: 2);
      await _settle();
      expect(provider.isPlaying, isTrue);
      gateway.log.clear();

      gateway.emitProcessingState(ProcessingState.completed);
      await _settle();

      expect(gateway.log, ['pause', 'seekToIndex']);
      expect(gateway.seekToIndexCalls, [0]);
      expect(provider.currentSong?.id, 1);
      expect(gateway.currentSong?.id, 1);
      expect(provider.isPlaying, isFalse);
      expect(gateway.playCalls, 1);

      // Previous must not walk back into the finished run.
      await provider.skipToPrevious();
      expect(gateway.seekToIndexCalls, [0]);
      expect(gateway.seekCalls, [Duration.zero]);
    });

    test('reshuffles and reloads the queue, paused, when shuffle is on', () async {
      final songs = List.generate(6, (i) => _song(i + 1));
      await provider.playSongsShuffled(songs);
      await _settle();
      gateway.log.clear();

      gateway.emitProcessingState(ProcessingState.completed);
      await _settle();

      expect(gateway.log, ['pause', 'load']);
      expect(provider.queue.map((s) => s.id).toSet(), {1, 2, 3, 4, 5, 6});
      expect(gateway.queue.map((s) => s.id), provider.queue.map((s) => s.id));
      expect(provider.currentSong, provider.queue.first);
      expect(gateway.currentIndex, 0);
      expect(provider.isPlaying, isFalse);
      expect(gateway.playCalls, 1);
    });

    test('a play request that arrives during the pause wins', () async {
      await provider.playSongs([_song(1), _song(2)]);
      gateway.blockPause = true;

      gateway.emitProcessingState(ProcessingState.completed);
      await _settle();
      expect(gateway.pendingPauses, hasLength(1));

      final play = provider.playSongs([_song(9)]);
      await _settle();
      gateway.pendingPauses.removeAt(0).complete();
      await play;
      await _settle();

      expect(provider.queue.map((s) => s.id), [9]);
      expect(provider.currentSong?.id, 9);
      expect(gateway.queue.map((s) => s.id), [9]);
      expect(gateway.seekToIndexCalls, isEmpty);
      expect(gateway.playCalls, 2);
    });

    test('shuffle loop still reshuffles and keeps playing', () async {
      final songs = List.generate(6, (i) => _song(i + 1));
      await provider.enableShuffleLoop(songs);
      await _settle();
      gateway.log.clear();

      gateway.emitProcessingState(ProcessingState.completed);
      await _settle();

      expect(gateway.log, ['load', 'play']);
      expect(gateway.pauseCalls, 0);
      expect(provider.repeatMode, RepeatMode.shuffleLoop);
      expect(provider.currentSong, provider.queue.first);
      expect(provider.isPlaying, isTrue);
    });
  });
}

/// Drains chained microtasks so awaiting code reaches its next suspension.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

SongItem _song(int id) => SongItem(
  id: id,
  title: 'Song $id',
  artist: 'Artist',
  album: 'Album',
  albumId: id,
  artistId: 1,
  data: '/music/$id.mp3',
  duration: 180000,
);

class _FakePlayerAudioGateway implements PlayerAudioGateway {
  final List<SongItem> queue = [];
  final List<int> seekToIndexCalls = [];
  final List<Duration> seekCalls = [];
  final _playingController = StreamController<bool>.broadcast();
  final _currentIndexController = StreamController<int?>.broadcast();
  final _processingStateController =
      StreamController<ProcessingState>.broadcast();
  int? currentIndex;
  /// Engine calls in order (load / play / pause / seekToIndex).
  final List<String> log = [];
  int pauseCalls = 0;
  bool blockPause = false;
  final List<Completer<void>> pendingPauses = [];
  bool failMove = false;
  bool failRemove = false;
  bool emitIndexOnSeek = false;
  int cancelledSubscriptions = 0;

  /// When true every loadSongs() clears the queue, then parks on a completer
  /// in [pendingLoads] until the test releases it — mirroring the async gap
  /// between ConcatenatingAudioSource.clear() and addAll().
  bool blockLoads = false;
  final List<Completer<void>> pendingLoads = [];
  int playCalls = 0;

  _FakePlayerAudioGateway() {
    _playingController.onCancel = _recordCancellation;
    _currentIndexController.onCancel = _recordCancellation;
    _processingStateController.onCancel = _recordCancellation;
  }

  void _recordCancellation() => cancelledSubscriptions++;

  void emitCurrentIndex(int index) {
    currentIndex = index;
    _currentIndexController.add(index);
  }

  void emitProcessingState(ProcessingState state) =>
      _processingStateController.add(state);

  Future<void> dispose() async {
    await Future.wait([
      _playingController.close(),
      _currentIndexController.close(),
      _processingStateController.close(),
    ]);
  }

  SongItem? get currentSong =>
      currentIndex == null || queue.isEmpty ? null : queue[currentIndex!];

  @override
  Future<void> loadSongs(List<SongItem> songs, {int initialIndex = 0}) async {
    log.add('load');
    queue.clear();
    if (blockLoads) {
      final gate = Completer<void>();
      pendingLoads.add(gate);
      await gate.future;
    }
    queue.addAll(songs);
    currentIndex = initialIndex;
  }

  @override
  Future<void> moveSong(int oldIndex, int newIndex) async {
    if (failMove) throw StateError('move failed');
    final song = queue.removeAt(oldIndex);
    queue.insert(newIndex, song);
    if (currentIndex == oldIndex) {
      currentIndex = newIndex;
    } else if (oldIndex < currentIndex! && newIndex >= currentIndex!) {
      currentIndex = currentIndex! - 1;
    } else if (oldIndex > currentIndex! && newIndex <= currentIndex!) {
      currentIndex = currentIndex! + 1;
    }
  }

  @override
  Future<void> removeSongAt(int index) async {
    if (failRemove) throw StateError('remove failed');
    queue.removeAt(index);
    if (queue.isEmpty) {
      currentIndex = null;
    } else if (index < currentIndex!) {
      currentIndex = currentIndex! - 1;
    } else if (index == currentIndex && currentIndex! >= queue.length) {
      currentIndex = queue.length - 1;
    }
  }

  @override
  Future<void> reorderTo(List<SongItem> newOrder) async {
    final activeId = currentSong?.id;
    queue
      ..clear()
      ..addAll(newOrder);
    currentIndex = queue.indexWhere((song) => song.id == activeId);
  }

  @override
  Future<void> addSongToQueue(SongItem song) async => queue.add(song);

  @override
  Future<void> pause() async {
    log.add('pause');
    pauseCalls++;
    if (blockPause) {
      final gate = Completer<void>();
      pendingPauses.add(gate);
      await gate.future;
    }
    _playingController.add(false);
  }

  @override
  Future<void> play() async {
    log.add('play');
    playCalls++;
    _playingController.add(true);
  }

  @override
  Future<void> seek(Duration position) async => seekCalls.add(position);

  @override
  Future<void> seekToIndex(int index) async {
    log.add('seekToIndex');
    seekToIndexCalls.add(index);
    currentIndex = index;
    if (emitIndexOnSeek) _currentIndexController.add(index);
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<int?> get currentIndexStream => _currentIndexController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<PositionData> get positionDataStream =>
      const Stream<PositionData>.empty();

  @override
  Stream<ProcessingState> get processingStateStream =>
      _processingStateController.stream;
}
