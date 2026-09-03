import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/services/audio_handler.dart';
import 'package:rxdart/rxdart.dart';

/// Regression tests for the frozen progress bar: after closing the mini player
/// with X (every listener of `positionDataStream` disposed) and playing another
/// song, the bar in both the mini player and Now Playing stayed at the old
/// position. `positionDataStream` used `.shareValue()`, whose refCount closes
/// the underlying subject once the last listener cancels, so every later
/// StreamBuilder only received the stale last value followed by `done`.
void main() {
  late BehaviorSubject<Duration> position;
  late BehaviorSubject<Duration> buffered;
  late BehaviorSubject<Duration?> duration;
  late PositionDataFeed feed;

  setUp(() {
    position = BehaviorSubject<Duration>.seeded(Duration.zero);
    buffered = BehaviorSubject<Duration>.seeded(Duration.zero);
    duration = BehaviorSubject<Duration?>.seeded(const Duration(minutes: 3));
    feed = PositionDataFeed(
      position: position,
      bufferedPosition: buffered,
      duration: duration,
    );
  });

  tearDown(() async {
    await feed.dispose();
    await position.close();
    await buffered.close();
    await duration.close();
  });

  test('replays the latest value to a new listener', () async {
    position.add(const Duration(seconds: 6));
    await pumpEventQueue();

    final first = await feed.stream.first;

    expect(first.position, const Duration(seconds: 6));
    expect(first.bufferedPosition, Duration.zero);
    expect(first.duration, const Duration(minutes: 3));
  });

  test(
    'keeps emitting to a listener that subscribes after all previous '
    'listeners cancelled',
    () async {
      // Mini player + Now Playing listen while a song plays.
      final firstListener = feed.stream.listen((_) {});
      position.add(const Duration(seconds: 6));
      await pumpEventQueue();

      // X on the mini player: currentSong = null, every StreamBuilder is
      // disposed and the listener count drops to zero.
      await firstListener.cancel();
      await pumpEventQueue();

      // The next song starts and a fresh mini player subscribes.
      final received = <Duration>[];
      var done = false;
      final secondListener = feed.stream.listen(
        (data) => received.add(data.position),
        onDone: () => done = true,
      );
      await pumpEventQueue();
      expect(received, [const Duration(seconds: 6)], reason: 'replayed value');

      position.add(Duration.zero);
      position.add(const Duration(seconds: 1));
      position.add(const Duration(seconds: 2));
      await pumpEventQueue();

      expect(received, [
        const Duration(seconds: 6),
        Duration.zero,
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
      expect(done, isFalse);
      await secondListener.cancel();
    },
  );

  test('maps an unknown duration to zero', () async {
    duration.add(null);
    await pumpEventQueue();

    final data = await feed.stream.first;

    expect(data.duration, Duration.zero);
  });
}
