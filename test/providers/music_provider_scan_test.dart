import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/models/playlist_item.dart';
import 'package:muziczz/models/song_item.dart';
import 'package:muziczz/providers/music_provider.dart';
import 'package:muziczz/services/music_scanner.dart';
import 'package:muziczz/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  test('a normal library refresh requests media permission once', () async {
    final scanner = _RecordingMusicScanner();
    final provider = MusicProvider(scanner: scanner);
    await provider.init();

    await provider.scanMusic();

    expect(scanner.permissionRequests, 1);
    expect(scanner.scanCalls, 1);
    expect(scanner.lastEnsurePermission, isFalse);
    expect(provider.status, LibraryStatus.done);
  });

  test('a normal library refresh does not trigger a deep media scan', () {
    final source = File('lib/services/music_scanner.dart').readAsStringSync();
    final scanSongsBody = _methodBody(source, 'scanSongs');

    expect(scanSongsBody, isNot(contains('.scanMedia(')));
    expect(scanSongsBody, contains('.querySongs('));
  });

  test('bulk hide uses one storage batch operation', () async {
    final storage = _RecordingStorageService();
    final provider = MusicProvider(storage: storage);
    await provider.init();
    final songs = List.generate(
      100,
      (index) => SongItem(
        id: index,
        title: 'Song $index',
        artist: 'Artist',
        album: 'Album',
        albumId: 1,
        artistId: 1,
        data: '/music/$index.mp3',
        duration: 60000,
      ),
    );

    await provider.hideSongsFromLibrary(songs);

    expect(storage.singleHideCalls, 0);
    expect(storage.batchHideCalls, 1);
    expect(storage.lastBatch, songs);
  });

  test('storage batch hide preserves existing hidden songs', () async {
    SharedPreferences.setMockInitialValues({
      'hidden_songs': jsonEncode({
        '99': {'title': 'Existing', 'artist': 'Artist', 'data': '/old.mp3'},
      }),
    });
    final storage = StorageService();
    await storage.init();
    const songs = [
      SongItem(
        id: 1,
        title: 'One',
        artist: 'Artist 1',
        album: 'Album',
        albumId: 1,
        artistId: 1,
        data: '/one.mp3',
        duration: 60000,
      ),
      SongItem(
        id: 2,
        title: 'Two',
        artist: 'Artist 2',
        album: 'Album',
        albumId: 1,
        artistId: 2,
        data: '/two.mp3',
        duration: 60000,
      ),
    ];

    await storage.hideSongs(songs);

    expect(storage.hiddenSongs.keys, containsAll(<int>[99, 1, 2]));
    expect(storage.hiddenSongs[1], {
      'title': 'One',
      'artist': 'Artist 1',
      'data': '/one.mp3',
    });
  });
}

String _methodBody(String source, String methodName) {
  final declaration = source.indexOf('$methodName(');
  expect(declaration, isNonNegative, reason: '$methodName must exist');

  final asyncMarker = source.indexOf('async {', declaration);
  expect(asyncMarker, isNonNegative, reason: '$methodName must be async');
  final openingBrace = source.indexOf('{', asyncMarker);
  expect(openingBrace, isNonNegative, reason: '$methodName must have a body');

  var depth = 0;
  for (var index = openingBrace; index < source.length; index++) {
    switch (source[index]) {
      case '{':
        depth++;
      case '}':
        depth--;
        if (depth == 0) {
          return source.substring(openingBrace + 1, index);
        }
    }
  }

  fail('Could not find the end of $methodName');
}

class _RecordingMusicScanner extends MusicScanner {
  int permissionRequests = 0;
  int scanCalls = 0;
  bool? lastEnsurePermission;

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return true;
  }

  @override
  Future<List<SongItem>> scanSongs({
    ScanProgressCallback? onProgress,
    bool ensurePermission = true,
  }) async {
    scanCalls += 1;
    lastEnsurePermission = ensurePermission;
    if (ensurePermission) await requestPermission();
    onProgress?.call(0);
    return const [];
  }
}

class _RecordingStorageService extends StorageService {
  int singleHideCalls = 0;
  int batchHideCalls = 0;
  List<SongItem> lastBatch = const [];

  @override
  Future<void> init() async {}

  @override
  List<PlaylistItem> get playlists => const [];

  @override
  Future<void> hideSong(
    int songId,
    String title,
    String artist,
    String data,
  ) async {
    singleHideCalls += 1;
  }

  @override
  Future<void> hideSongs(List<SongItem> songs) async {
    batchHideCalls += 1;
    lastBatch = songs;
  }

  @override
  Future<void> savePlaylists(List<PlaylistItem> playlists) async {}
}
