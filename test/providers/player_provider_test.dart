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

  tearDown(() {
    provider.dispose();
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
  int? currentIndex;
  bool failMove = false;
  bool failRemove = false;

  SongItem? get currentSong =>
      currentIndex == null || queue.isEmpty ? null : queue[currentIndex!];

  @override
  Future<void> loadSongs(List<SongItem> songs, {int initialIndex = 0}) async {
    queue
      ..clear()
      ..addAll(songs);
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
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> seekToIndex(int index) async => currentIndex = index;

  @override
  Future<void> setLoopMode(LoopMode mode) async {}

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<int?> get currentIndexStream => const Stream<int?>.empty();

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<PositionData> get positionDataStream =>
      const Stream<PositionData>.empty();

  @override
  Stream<ProcessingState> get processingStateStream =>
      const Stream<ProcessingState>.empty();
}
