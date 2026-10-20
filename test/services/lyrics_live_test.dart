import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:muziczz/models/song_item.dart';
import 'package:muziczz/services/lyrics_service.dart';

// Opt-in network smoke check; normal test runs remain offline/deterministic.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'live LRCLIB resolves the reported untagged remix',
    () async {
      final previousOverride = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previousOverride);
      final dir = await Directory.systemTemp.createTemp('lyrics_live_');
      addTearDown(() => dir.delete(recursive: true));
      final service = LyricsService(
        directory: () async => dir,
        embeddedReader: (_) async => null,
      );
      addTearDown(service.dispose);
      const title =
          'Anh Đau Từ Lúc Em Đi - Trần Mạnh Cường (Duzme Remix) '
          'Ngày Đó Anh Ngỡ Chỉ Là Lời Nói⧸Official Lyrics';
      final result = await service.load(
        const SongItem(
          id: 101,
          title: title,
          artist: '<unknown>',
          album: '<unknown>',
          albumId: 0,
          artistId: 0,
          data: '/music/$title.m4a',
          duration: 323361,
        ),
        LyricsSourcePreference.apiFirst,
      );
      expect(result.source, 'LRCLIB');
      expect(result.isSynced, isTrue);
      expect(result.lines.length, greaterThan(10));
      // Report counts only; no copyrighted lyrics in logs or fixtures.
      // ignore: avoid_print
      print(
        'Live result: ${result.lines.length} timed lines from ${result.source}',
      );
    },
    skip: !const bool.fromEnvironment('LYRICS_LIVE'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
