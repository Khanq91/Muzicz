import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/models/song_item.dart';
import 'package:muziczz/services/music_scanner.dart';
import 'package:muziczz/services/webm_audio_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('music_scanner_channel');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps native WebM metadata into a playable song item', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'scanWebmAudio');
          return json.encode([
            {
              'id': -42,
              'title': 'WebM song',
              'artist': 'Artist',
              'album': 'Album',
              'albumId': 0,
              'artistId': 0,
              'data': '/storage/emulated/0/Music/song.webm',
              'duration': 120000,
              'size': 1000,
              'track': null,
              'dateAdded': 1000,
            },
          ]);
        });

    final songs = await const MethodChannelWebmAudioGateway().scan();

    expect(songs, hasLength(1));
    expect(songs.single.id, -42);
    expect(songs.single.data, endsWith('.webm'));
    expect(songs.single.duration, 120000);
  });

  test('merge keeps MediaStore Audio metadata and deduplicates paths', () {
    final primary = _song(
      id: 10,
      title: 'Primary metadata',
      path: '/Music/Song.webm',
      added: DateTime(2026, 1, 1),
    );
    final duplicateFallback = _song(
      id: -10,
      title: 'Fallback metadata',
      path: '/music/song.WEBM',
      added: DateTime(2026, 2, 1),
    );
    final newFallback = _song(
      id: -11,
      title: 'New WebM',
      path: '/Music/new.webm',
      added: DateTime(2026, 3, 1),
    );

    final merged = mergeScannedSongs(
      [primary],
      [duplicateFallback, newFallback],
    );

    expect(merged, hasLength(2));
    expect(merged.first, newFallback);
    expect(merged.last, primary);
  });
}

SongItem _song({
  required int id,
  required String title,
  required String path,
  required DateTime added,
}) => SongItem(
  id: id,
  title: title,
  artist: 'Artist',
  album: 'Album',
  albumId: 0,
  artistId: 0,
  data: path,
  duration: 60000,
  dateAdded: added,
);
