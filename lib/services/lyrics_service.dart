import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/lyric_line.dart';
import '../models/song_item.dart';
import '../utils/vietnamese_normalize.dart';
import 'embedded_lyrics_reader.dart';
import 'lyrics_parser.dart';

enum LyricsResultType { synced, plain, instrumental, notFound, error }

enum LyricsSourcePreference { embeddedFirst, apiFirst, localFirst }

class LyricsResult {
  const LyricsResult({
    required this.type,
    this.lines = const [],
    this.raw = '',
    this.source = '',
    this.message,
  });
  factory LyricsResult.synced(List<LyricLine> lines) => LyricsResult(
    type: LyricsResultType.synced,
    lines: lines,
    raw: LyricsParser.export(lines),
  );
  factory LyricsResult.plain(List<LyricLine> lines) => LyricsResult(
    type: LyricsResultType.plain,
    lines: lines,
    raw: LyricsParser.export(lines, synced: false),
  );
  factory LyricsResult.notFound() =>
      const LyricsResult(type: LyricsResultType.notFound);
  factory LyricsResult.error([String? message]) =>
      LyricsResult(type: LyricsResultType.error, message: message);
  factory LyricsResult.parse(String raw, {required String source}) {
    final lines = LyricsParser.parse(raw);
    if (!lines.any((l) => l.text.isNotEmpty)) {
      throw const FormatException('Không có nội dung lời');
    }
    return LyricsResult(
      type:
          lines.any((l) => l.time != null)
              ? LyricsResultType.synced
              : LyricsResultType.plain,
      lines: lines,
      raw: raw,
      source: source,
    );
  }
  final LyricsResultType type;
  final List<LyricLine> lines;
  final String raw, source;
  final String? message;
  bool get isSynced => type == LyricsResultType.synced;
  bool get hasLyrics => lines.isNotEmpty;
}

class LyricsCandidate {
  LyricsCandidate.fromJson(Map<String, dynamic> json)
    : id = json['id'].toString(),
      title = (json['trackName'] ?? json['name'] ?? '').toString(),
      artist = (json['artistName'] ?? '').toString(),
      album = (json['albumName'] ?? '').toString(),
      duration = (json['duration'] as num?)?.toDouble() ?? 0,
      synced = (json['syncedLyrics'] as String?) ?? '',
      plain = (json['plainLyrics'] as String?) ?? '',
      instrumental = json['instrumental'] == true;
  final String id, title, artist, album, synced, plain;
  final double duration;
  final bool instrumental;
  LyricsResult get result =>
      instrumental && synced.trim().isEmpty && plain.trim().isEmpty
          ? const LyricsResult(
            type: LyricsResultType.instrumental,
            source: 'LRCLIB',
          )
          : LyricsResult.parse(
            synced.trim().isNotEmpty ? synced : plain,
            source: 'LRCLIB',
          );
}

class LyricsService {
  LyricsService({
    http.Client? client,
    Future<Directory> Function()? directory,
    Future<String?> Function(String)? embeddedReader,
  }) : _client = client ?? http.Client(),
       _directory = directory ?? getApplicationSupportDirectory,
       _embeddedReader = embeddedReader ?? EmbeddedLyricsReader().read;
  final http.Client _client;
  final Future<Directory> Function() _directory;
  final Future<String?> Function(String) _embeddedReader;
  final Map<String, LyricsResult> _memory = {};
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _networkTail = Future.value();
  final Map<String, Future<void>> _writes = {};
  static List<LyricLine> parseLrc(String raw) =>
      LyricsParser.parse(raw).where((l) => l.time != null).toList();
  static String key(SongItem song) =>
      sha256
          .convert(
            utf8.encode(
              '${song.data}\u0000${song.title}\u0000${song.artist}\u0000${song.duration}',
            ),
          )
          .toString();

  Future<File> _file(SongItem song) async {
    final root = await _directory();
    final dir = await Directory('${root.path}/lyrics').create(recursive: true);
    return File('${dir.path}/${key(song)}.json');
  }

  Future<LyricsResult?> stored(SongItem song) async {
    final id = key(song);
    if (_memory.containsKey(id)) return _memory[id];
    try {
      final file = await _file(song);
      if (!await file.exists() || await file.length() > 2 * 1024 * 1024) {
        return null;
      }
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final result =
          json['instrumental'] == true
              ? LyricsResult(
                type: LyricsResultType.instrumental,
                source: json['source'] as String? ?? '',
              )
              : LyricsResult.parse(
                json['raw'] as String,
                source: json['source'] as String? ?? 'Đã lưu',
              );
      _remember(id, result);
      return result;
    } catch (_) {
      return null;
    }
  }

  void _remember(String id, LyricsResult result) {
    _memory.remove(id);
    _memory[id] = result;
    if (_memory.length > 150) _memory.remove(_memory.keys.first);
  }

  Future<void> save(SongItem song, LyricsResult result) {
    final id = key(song);
    final next = (_writes[id] ?? Future<void>.value()).catchError((_) {}).then((
      _,
    ) async {
      final file = await _file(song);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        jsonEncode({
          'raw': result.raw,
          'source': result.source,
          'instrumental': result.type == LyricsResultType.instrumental,
        }),
        flush: true,
      );
      await temp.rename(file.path);
      _remember(id, result);
    });
    _writes[id] = next;
    return next;
  }

  Future<void> remove(SongItem song) async {
    final id = key(song);
    await (_writes[id] ?? Future<void>.value()).catchError((_) {});
    final file = await _file(song);
    if (await file.exists()) await file.delete();
    _memory.remove(id);
  }

  Future<LyricsResult> load(
    SongItem song,
    LyricsSourcePreference preference, {
    bool refresh = false,
  }) async {
    if (!refresh) {
      final cached = await stored(song);
      if (cached != null) return cached;
    }
    Future<LyricsResult?> embedded() async {
      final raw = await _embeddedReader(song.data);
      return raw == null || raw.trim().isEmpty
          ? null
          : LyricsResult.parse(raw, source: 'Nhúng trong file');
    }

    Future<LyricsResult?> local() => findSidecar(song);
    Future<LyricsResult?> online() async {
      final results = await search(
        song.title,
        song.artist,
        song: song,
        automatic: true,
      );
      return results.isEmpty ? null : results.first.result;
    }

    final sources = switch (preference) {
      LyricsSourcePreference.embeddedFirst => [embedded, online, local],
      LyricsSourcePreference.apiFirst => [online, embedded, local],
      LyricsSourcePreference.localFirst => [local, embedded, online],
    };
    var networkFailed = false;
    for (final source in sources) {
      try {
        final result = await source();
        if (result != null) return result;
      } on LyricsNetworkException {
        networkFailed = true;
      } on PlatformException {
        /* Unreadable native metadata must not block remaining sources. */
      } on FileSystemException {
        /* Try remaining sources. */
      } on FormatException {
        /* Invalid metadata must not block fallback. */
      }
    }
    return networkFailed
        ? LyricsResult.error(
          'Không thể kết nối LRCLIB. Hãy thử lại hoặc nhập file lời.',
        )
        : LyricsResult.notFound();
  }

  Future<LyricsResult?> findSidecar(SongItem song) async {
    final file = File(song.data);
    final stem = file.uri.pathSegments.last.replaceFirst(
      RegExp(r'\.[^.]+$'),
      '',
    );
    final alternative = '${song.artist}_${song.title}'.replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '_',
    );
    for (final name in {stem, alternative}) {
      for (final ext in ['lrc', 'ttml', 'txt']) {
        final candidate = File('${file.parent.path}/$name.$ext');
        try {
          if (await candidate.exists() &&
              await candidate.length() <= maxBytes(ext)) {
            return importBytes(
              await candidate.readAsBytes(),
              '$name.$ext',
              source: 'File đi kèm',
            );
          }
        } on FormatException {
          continue;
        }
      }
    }
    return null;
  }

  static int maxBytes(String ext) =>
      ext.toLowerCase() == 'ttml' ? 1024 * 1024 : 256 * 1024;
  static LyricsResult importBytes(
    List<int> bytes,
    String filename, {
    String source = 'Đã nhập',
  }) {
    final ext = filename.split('.').last.toLowerCase();
    if (!['lrc', 'ttml', 'txt'].contains(ext)) {
      throw const FormatException('Chọn file .lrc, .ttml hoặc .txt');
    }
    if (bytes.length > maxBytes(ext)) {
      throw const FormatException('File lời quá lớn');
    }
    final raw = LyricsParser.decode(bytes);
    if (raw.contains('\u0000')) {
      throw const FormatException('File không phải văn bản lyrics');
    }
    return LyricsResult.parse(raw, source: source);
  }

  // Ported from PixelPlayer's remote matcher. Search cleanup and matching
  // cleanup intentionally differ: meaningful qualifiers must survive matching.
  static final _brackets = RegExp(
    r'[\(\[\{（［｛【『「〔〈《]([^\)\]\}）］｝】』」〕〉》]*)[\)\]\}）］｝】』」〕〉》]',
  );
  static final _separator = RegExp(r'\s*[-–—:－·・]\s*');
  static final _feature = RegExp(
    r'\b(feat(?:uring)?|ft)\.?\b',
    caseSensitive: false,
  );
  static const _timingWords = {
    'remix',
    'mix',
    'mashup',
    'bootleg',
    'edit',
    'extended',
    'radio',
    'club',
    'vip',
    'dub',
    'live',
    'acoustic',
    'unplugged',
    'sped',
    'slowed',
    'nightcore',
    'instrumental',
    'karaoke',
    'cover',
    'demo',
    'version',
    'rework',
    'flip',
    'refix',
    'opening',
    'ending',
    'op',
    'ed',
    'theme',
    'tv',
    'size',
    'ver',
    'full',
    'movie',
    'ost',
    'soundtrack',
    'background',
    'bgm',
    'short',
    'long',
    'reprise',
    'intro',
    'outro',
    'medley',
    'bonus',
  };
  static String clean(String value) =>
      value.replaceAll(_brackets, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  static String _simplify(String value) =>
      value
          .split(
            RegExp(r' feat\.| ft\.| featuring| & | , ', caseSensitive: false),
          )
          .first
          .trim();
  static String _smartTitle(String value) =>
      value
          .replaceFirst(RegExp(r'^[\d\s.\-－]+'), '')
          .split(RegExp(r'[-(\[\{（［｛【『「〔〈《]'))
          .first
          .trim();
  static String normalize(String value) => vnNormalize(value)
      .replaceAll('&', ' and ')
      .replaceAll(RegExp("[’'`]"), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  static Set<String> _tokens(String value) =>
      value.split(' ').where((token) => token.isNotEmpty).toSet();
  static Set<String> _variants(String value) {
    final normalized = normalize(value);
    final tokens = _tokens(normalized);
    return {
      ...tokens.intersection(_timingWords),
      if (RegExp(r'\bmash\s+up\b').hasMatch(normalized) ||
          tokens.contains('vs') ||
          tokens.contains('versus'))
        'mashup',
    };
  }

  static bool _dropQualifier(String value) =>
      normalize(value).isEmpty ||
      _feature.hasMatch(value) ||
      _variants(value).isNotEmpty ||
      {
        'explicit',
        'clean',
        'mono',
        'stereo',
        'official audio',
        'official video',
        'hi res',
        'high res',
        'mqa',
      }.contains(normalize(value));
  static String _baseTitle(String value) {
    var base = value.replaceFirst(RegExp(r'^\s*\d{1,3}[._-]?\s+'), '');
    base = base.replaceAllMapped(
      _brackets,
      (m) => _dropQualifier(m[1]!) ? ' ' : ' ${m[1]} ',
    );
    final parts = base.split(_separator);
    while (parts.length > 1 && _dropQualifier(parts.last)) {
      parts.removeLast();
    }
    return normalize(parts.join(' '));
  }

  static Set<String> _fileVariants(SongItem song) {
    final filename = song.data
        .split(RegExp(r'[/\\]'))
        .last
        .replaceFirst(RegExp(r'\.[^.]+$'), '');
    final base = _baseTitle(song.title);
    return {
      for (final match in _brackets.allMatches(filename))
        ..._variants(match[1]!),
      if (base.isNotEmpty)
        for (final part in filename.split(_separator))
          if (normalize(part).startsWith('$base '))
            ..._variants(normalize(part).substring(base.length).trim()),
    };
  }

  static bool _unknown(String artist) => {
    '',
    'unknown',
    'unknown artist',
    'various artists',
    'various',
    'nghe si khong xac dinh',
  }.contains(normalize(artist));
  static bool _phrase(String a, String b) =>
      ' $a '.contains(' $b ') || ' $b '.contains(' $a ');
  static double? score(SongItem song, LyricsCandidate item) {
    if (item.synced.trim().isEmpty && item.plain.trim().isEmpty) return null;
    if (song.duration <= 0 || item.duration <= 0) return null;
    final variants = {..._variants(song.title), ..._fileVariants(song)};
    final other = _variants(item.title);
    if (variants.length != other.length || !variants.containsAll(other)) {
      return null;
    }
    final synced = item.synced.trim().isNotEmpty;
    final tolerance = (song.duration / 1000 * (synced ? .02 : .04)).clamp(
      synced ? 5 : 8,
      synced ? 8 : 15,
    );
    final difference = (item.duration - song.duration / 1000).abs();
    if (difference > tolerance) return null;
    final a = _baseTitle(song.title), b = _baseTitle(item.title);
    if (a.isEmpty || b.isEmpty) return null;
    var titleScore = 70.0;
    if (a != b) {
      final aa = _tokens(a), bb = _tokens(b);
      if (aa.length == 1 || bb.length == 1) {
        final compactA = a.replaceAll(' ', ''),
            compactB = b.replaceAll(' ', '');
        if (!compactA.contains(compactB) && !compactB.contains(compactA)) {
          return null;
        }
        titleScore = 55;
      } else if (_phrase(a, b)) {
        titleScore = 58;
      } else {
        final overlap = aa.intersection(bb).length;
        if (overlap / aa.length < .85 || overlap / bb.length < .70) return null;
        titleScore = 45;
      }
    }
    var artistScore = 0.0;
    if (!_unknown(song.artist)) {
      final a = normalize(song.artist), b = normalize(item.artist);
      if (a.isEmpty || b.isEmpty) return null;
      if (a == b) {
        artistScore = 30;
      } else if (_phrase(a, b)) {
        artistScore = 22;
      } else {
        const connectors = {
          'feat',
          'featuring',
          'ft',
          'and',
          'with',
          'x',
          'vs',
          'the',
        };
        final aa = _tokens(a).difference(connectors),
            bb = _tokens(b).difference(connectors);
        final denominator = aa.length < bb.length ? aa.length : bb.length;
        if (denominator == 0 || aa.intersection(bb).length / denominator < .5) {
          return null;
        }
        artistScore = 12;
      }
    }
    return titleScore +
        artistScore +
        (tolerance - difference).floor() +
        (synced ? 10 : 0);
  }

  Future<List<LyricsCandidate>> search(
    String title,
    String artist, {
    SongItem? song,
    bool automatic = false,
  }) async {
    if (title.trim().isEmpty) return [];
    final cleanTitle = clean(title), cleanArtist = clean(artist);
    final queries = <Map<String, String>>[
      {
        'track_name': title.trim(),
        if (!_unknown(artist)) 'artist_name': artist.trim(),
      },
      {
        'track_name': cleanTitle,
        if (!_unknown(cleanArtist)) 'artist_name': cleanArtist,
      },
      {'q': '$cleanArtist $cleanTitle'.trim()},
      {
        'track_name': _simplify(cleanTitle),
        if (!_unknown(cleanArtist)) 'artist_name': _simplify(cleanArtist),
      },
      if (_smartTitle(cleanTitle).isNotEmpty)
        {'track_name': _smartTitle(cleanTitle)},
      {'track_name': cleanTitle},
      {'q': cleanTitle},
      if (cleanTitle.split(RegExp(r'[-,():－·・]')).first.trim().isNotEmpty)
        {'track_name': cleanTitle.split(RegExp(r'[-,():－·・]')).first.trim()},
    ];
    SongItem? romanSong;
    try {
      final roman = await const MethodChannel(
        'muzicz/lyrics',
      ).invokeMethod<String>('romanize', '$cleanTitle\n$cleanArtist');
      if (roman != null && roman != '$cleanTitle\n$cleanArtist') {
        final parts = roman.split('\n');
        queries.add({'track_name': parts.first});
        if (song != null) {
          romanSong = SongItem(
            id: song.id,
            title: parts.first,
            artist: parts.length > 1 ? parts[1] : song.artist,
            album: song.album,
            albumId: song.albumId,
            artistId: song.artistId,
            data: song.data,
            duration: song.duration,
          );
        }
      }
    } on MissingPluginException {
      /* Optional Android transliteration. */
    } on PlatformException {
      /* Try original metadata. */
    }
    double? match(LyricsCandidate item) =>
        song == null
            ? null
            : score(song, item) ??
                (romanSong == null ? null : score(romanSong, item));
    if (automatic && song != null && song.duration > 0 && !_unknown(artist)) {
      try {
        final exact = await _request('get', {
          'track_name': title,
          'artist_name': artist,
          'album_name': song.album,
          'duration': (song.duration / 1000).round().toString(),
        });
        if (exact is Map<String, dynamic>) {
          final candidate = LyricsCandidate.fromJson(exact);
          if (match(candidate) != null) return [candidate];
        }
      } on LyricsNetworkException {
        /* Search fallback remains available. */
      }
    }
    final found = <String, LyricsCandidate>{}, tried = <String>{};
    var failures = 0;
    for (final query in queries) {
      if (!tried.add(jsonEncode(query))) continue;
      try {
        final json = await _request('search', query);
        if (json is List) {
          for (final entry in json.take(200)) {
            if (entry is! Map<String, dynamic>) continue;
            final item = LyricsCandidate.fromJson(entry);
            if (item.instrumental ||
                item.synced.trim().isNotEmpty ||
                item.plain.trim().isNotEmpty) {
              found[item.id] = item;
            }
          }
        }
        if (automatic &&
            song != null &&
            found.values.any((c) => match(c) != null)) {
          break;
        }
      } on LyricsNetworkException {
        failures++;
      }
    }
    if (found.isEmpty && failures == tried.length) {
      throw const LyricsNetworkException();
    }
    final result =
        found.values
            .where((c) => !automatic || (song != null && match(c) != null))
            .toList();
    if (song != null) {
      result.sort((a, b) => (match(b) ?? -1).compareTo(match(a) ?? -1));
    }
    return result;
  }

  Future<dynamic> _request(String endpoint, Map<String, String> query) {
    final completer = Completer<dynamic>();
    _networkTail = _networkTail.catchError((_) {}).then((_) async {
      try {
        for (var attempt = 0; attempt < 3; attempt++) {
          final wait =
              150 - DateTime.now().difference(_lastRequest).inMilliseconds;
          if (wait > 0) {
            await Future<void>.delayed(Duration(milliseconds: wait));
          }
          _lastRequest = DateTime.now();
          http.Response response;
          try {
            response = await _client
                .get(
                  Uri.https('lrclib.net', '/api/$endpoint', query),
                  headers: {
                    'User-Agent': 'MuziczAudio/2.0 (Android music player)',
                  },
                )
                .timeout(const Duration(seconds: 12));
          } on Exception {
            if (attempt == 2) rethrow;
            await Future<void>.delayed(
              Duration(milliseconds: 500 * (1 << attempt)),
            );
            continue;
          }
          if (response.statusCode == 404) {
            completer.complete(<dynamic>[]);
            return;
          }
          if (response.statusCode == 200) {
            if (response.bodyBytes.length > 8 * 1024 * 1024) {
              throw const LyricsNetworkException();
            }
            completer.complete(jsonDecode(utf8.decode(response.bodyBytes)));
            return;
          }
          if (response.statusCode != 429 && response.statusCode < 500) break;
          await Future<void>.delayed(
            Duration(milliseconds: 500 * (1 << attempt)),
          );
        }
        throw const LyricsNetworkException();
      } catch (_) {
        completer.completeError(const LyricsNetworkException());
      }
    });
    return completer.future;
  }

  void dispose() => _client.close();
}

class LyricsNetworkException implements Exception {
  const LyricsNetworkException();
  @override
  String toString() => 'Không thể kết nối máy chủ lyrics. Vui lòng thử lại.';
}
