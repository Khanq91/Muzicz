import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/models/song_item.dart';
import 'package:muziczz/providers/music_provider.dart';
import 'package:muziczz/services/music_scanner.dart';
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
