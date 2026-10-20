import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muziczz/models/song_item.dart';
import 'package:muziczz/providers/lyrics_provider.dart';
import 'package:muziczz/services/lyrics_parser.dart';
import 'package:muziczz/services/lyrics_service.dart';
import 'package:muziczz/services/embedded_lyrics_reader.dart';

SongItem song(
  int id, {
  String title = 'Đêm nay',
  String artist = 'Ca sĩ',
  String? path,
}) => SongItem(
  id: id,
  title: title,
  artist: artist,
  album: 'Album',
  albumId: 1,
  artistId: 1,
  data: path ?? '/music/$id.mp3',
  duration: 180000,
);
Map<String, dynamic> candidate({
  int id = 1,
  String title = 'Đêm nay',
  String artist = 'Ca sĩ',
  double duration = 180,
}) => {
  'id': id,
  'trackName': title,
  'artistName': artist,
  'duration': duration,
  'syncedLyrics': '[00:01.00]Hello\n[00:03.00]World',
};
List<int> big(int n, int count) => [
  for (var i = count - 1; i >= 0; i--) (n >> (8 * i)) & 255,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'LRC supports seconds, fractional precision, repeated tags, offset and words',
    () {
      final lines = LyricsParser.parse(
        '[ar:Artist]\n[offset:100]\n[00:01.5][00:04]Again\n[00:02.000]<00:02.000>Hello <00:02.500>world',
      );
      expect(lines.map((l) => l.time!.inMilliseconds), [1600, 2100, 4100]);
      expect(lines[1].words.map((w) => w.start.inMilliseconds), [2100, 2600]);
      expect(lines[1].words.first.text, 'Hello ');
      final exported = LyricsParser.export(lines);
      expect(LyricsParser.parse(exported)[1].words.length, 2);
    },
  );
  test('TTML retains word timing, translation and romanization', () {
    final lines = LyricsParser.parse(
      '''<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata"><body><div>
    <p begin="1s" end="4s"><span begin="1s" end="2s">Hello </span><span begin="2s" end="4s">world</span><span ttm:role="x-translation">Xin chào</span><span ttm:role="x-roman">hello</span></p>
    </div></body></tt>''',
    );
    expect(lines.single.text, 'Hello world');
    expect(lines.single.words.length, 2);
    expect(lines.single.translation, 'Xin chào');
    expect(lines.single.romanization, 'hello');
    expect(lines.single.end!.inSeconds, 4);
  });
  test(
    'imports validate encoding, format and size; plain text remains available',
    () {
      expect(
        LyricsService.importBytes(utf8.encode('Xin chào'), 'song.txt').type,
        LyricsResultType.plain,
      );
      final utf16 = [
        255,
        254,
        for (final c in '[00:01]Hi'.codeUnits) ...[c & 255, c >> 8],
      ];
      expect(
        LyricsService.importBytes(utf16, 'SONG.LRC').lines.single.text,
        'Hi',
      );
      expect(
        () => LyricsService.importBytes([255, 0, 0], 'x.lrc'),
        throwsFormatException,
      );
      expect(
        () =>
            LyricsService.importBytes(List.filled(256 * 1024 + 1, 65), 'x.lrc'),
        throwsFormatException,
      );
      expect(
        () => LyricsService.importBytes([65], 'x.exe'),
        throwsFormatException,
      );
      expect(() => LyricsParser.parse('<tt><broken>'), throwsFormatException);
      expect(
        () => LyricsParser.parse('<!DOCTYPE tt><tt/>'),
        throwsFormatException,
      );
    },
  );
  test('metadata extracts ID3 USLT and FLAC Vorbis lyrics', () {
    final payload = [
      3,
      ...ascii.encode('eng'),
      0,
      ...utf8.encode('[00:01]Embedded'),
    ];
    final frame = [
      ...ascii.encode('USLT'),
      ...big(payload.length, 4),
      0,
      0,
      ...payload,
    ];
    final bytes = Uint8List.fromList([
      ...ascii.encode('ID3'),
      3,
      0,
      0,
      0,
      0,
      frame.length >> 7,
      frame.length & 127,
      ...frame,
    ]);
    expect(EmbeddedLyricsReader.parse(bytes), '[00:01]Embedded');
    final comment = utf8.encode('LYRICS=[00:02]Flac');
    final block = [
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      ...big(comment.length, 4).reversed,
      ...comment,
    ];
    expect(
      EmbeddedLyricsReader.parse(
        Uint8List.fromList([
          ...ascii.encode('fLaC'),
          132,
          ...big(block.length, 3),
          ...block,
        ]),
      ),
      '[00:02]Flac',
    );
  });
  test(
    'M4A seeks metadata after audio data and closes only after read',
    () async {
      final dir = await Directory.systemTemp.createTemp('muzicz_mp4_');
      addTearDown(() => dir.delete(recursive: true));
      List<int> atom(String type, List<int> body) => [
        ...big(body.length + 8, 4),
        ...latin1.encode(type),
        ...body,
      ];
      final lyric = atom(
        '©lyr',
        atom('data', [...List.filled(8, 0), ...utf8.encode('M4A words')]),
      );
      final file = File('${dir.path}/song.m4a');
      await file.writeAsBytes([
        ...atom('ftyp', List.filled(8, 0)),
        ...atom('mdat', List.filled(2200000, 0)),
        ...atom(
          'moov',
          atom('udta', atom('meta', [0, 0, 0, 0, ...atom('ilst', lyric)])),
        ),
      ]);
      expect(await EmbeddedLyricsReader().read(file.path), 'M4A words');
    },
  );
  test(
    'matching rejects wrong artists, duration and remix, keeps cleaned metadata',
    () {
      expect(
        LyricsService.score(
          song(1, title: '01 Đêm nay (Official Video)'),
          LyricsCandidate.fromJson(candidate()),
        ),
        isNotNull,
      );
      expect(
        LyricsService.score(
          song(1),
          LyricsCandidate.fromJson(candidate(artist: 'Someone else')),
        ),
        isNull,
      );
      expect(
        LyricsService.score(
          song(1),
          LyricsCandidate.fromJson(candidate(duration: 210)),
        ),
        isNull,
      );
      expect(
        LyricsService.score(
          song(1),
          LyricsCandidate.fromJson(candidate(title: 'Đêm nay remix')),
        ),
        isNull,
      );
      expect(
        LyricsService.score(
          song(1, artist: '<unknown>'),
          LyricsCandidate.fromJson(candidate()),
        ),
        isNotNull,
      );
    },
  );
  test(
    'online fallback after exact miss filters mismatches and keeps provenance offline',
    () async {
      final dir = await Directory.systemTemp.createTemp('muzicz_lyrics_');
      addTearDown(() => dir.delete(recursive: true));
      final requests = <Uri>[];
      final service = LyricsService(
        directory: () async => dir,
        embeddedReader: (_) async => null,
        client: MockClient((request) async {
          requests.add(request.url);
          if (request.url.path.endsWith('/get'))
            return http.Response('{}', 404);
          return http.Response(
            utf8.decode(
              utf8.encode(
                jsonEncode([candidate(id: 2, artist: 'Wrong'), candidate()]),
              ),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.dispose);
      final result = await service.load(
        song(1),
        LyricsSourcePreference.apiFirst,
      );
      expect(result.lines.first.text, 'Hello');
      expect(
        requests.map((u) => u.path),
        containsAll(['/api/get', '/api/search']),
      );
      await service.save(song(1), result);
      final offline = LyricsService(
        directory: () async => dir,
        client: MockClient(
          (_) async => throw StateError('must not call network'),
        ),
      );
      addTearDown(offline.dispose);
      expect(
        (await offline.load(song(1), LyricsSourcePreference.apiFirst)).source,
        'LRCLIB',
      );
      expect(
        LyricsService.key(song(1, title: 'Đêm')),
        isNot(LyricsService.key(song(1, title: 'Đèn'))),
      );
    },
  );
  test(
    'local priority finds sidecars without network and manual import survives source changes',
    () async {
      final dir = await Directory.systemTemp.createTemp('muzicz_local_');
      addTearDown(() => dir.delete(recursive: true));
      final target = song(1, path: '${dir.path}/track.mp3');
      await File('${dir.path}/track.lrc').writeAsString('[00:01]Local');
      final service = LyricsService(
        directory: () async => dir,
        client: MockClient((_) async => throw StateError('network')),
      );
      addTearDown(service.dispose);
      expect(
        (await service.load(target, LyricsSourcePreference.localFirst)).source,
        'File đi kèm',
      );
      await service.save(
        target,
        LyricsResult.parse('Manual', source: 'Đã nhập'),
      );
      expect(
        (await service.load(
          target,
          LyricsSourcePreference.apiFirst,
        )).lines.single.text,
        'Manual',
      );
      await service.remove(target);
      expect(await service.stored(target), isNull);
    },
  );
  test(
    'provider drops stale responses, preserves assignments and persists offsets',
    () async {
      final service = _PendingService();
      final provider = LyricsProvider(service: service);
      addTearDown(provider.dispose);
      await provider.initialize();
      final first = provider.loadLyrics(song(1));
      await Future<void>.delayed(Duration.zero);
      final second = provider.loadLyrics(song(2));
      await Future<void>.delayed(Duration.zero);
      service.requests[2]!.complete(
        LyricsResult.parse('[00:01]<00:01>New <00:02>word', source: 'Test'),
      );
      await second;
      service.requests[1]!.complete(
        LyricsResult.parse('Stale', source: 'Test'),
      );
      await first;
      expect(provider.lines.single.text, 'New word');
      provider.updatePosition(const Duration(milliseconds: 900));
      expect(provider.currentIndex, -1);
      await provider.setOffset(200);
      expect(provider.currentIndex, 0);
      expect(provider.currentWord, 0);
      expect(provider.seekPosition(provider.lines.first).inMilliseconds, 800);
      await provider.assign(
        song(1),
        LyricsResult.parse('For old song', source: 'Manual'),
      );
      expect(provider.state.songId, 2);
      expect(provider.lines.single.text, 'New word');
      expect(
        (await SharedPreferences.getInstance()).getInt(
          'lyrics_offset_${LyricsService.key(song(2))}',
        ),
        200,
      );
    },
  );
}

class _PendingService extends LyricsService {
  final requests = <int, Completer<LyricsResult>>{};
  @override
  Future<LyricsResult> load(
    SongItem song,
    LyricsSourcePreference preference, {
    bool refresh = false,
  }) => (requests[song.id] = Completer<LyricsResult>()).future;
  @override
  Future<void> save(SongItem song, LyricsResult result) async {}
}
