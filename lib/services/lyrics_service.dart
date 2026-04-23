import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/lyric_line.dart';

// ════════════════════════════════════════════════════════════════════════════
// LyricsResult — sealed-ish result type
// ════════════════════════════════════════════════════════════════════════════

enum LyricsResultType { synced, plain, notFound, error }

class LyricsResult {
  const LyricsResult._({
    required this.type,
    this.lines = const [],
    this.errorMessage,
  });

  factory LyricsResult.synced(List<LyricLine> lines) =>
      LyricsResult._(type: LyricsResultType.synced, lines: lines);

  factory LyricsResult.plain(List<LyricLine> lines) =>
      LyricsResult._(type: LyricsResultType.plain, lines: lines);

  factory LyricsResult.notFound() =>
      const LyricsResult._(type: LyricsResultType.notFound);

  factory LyricsResult.error(String message) =>
      LyricsResult._(type: LyricsResultType.error, errorMessage: message);

  final LyricsResultType type;
  final List<LyricLine> lines;
  final String? errorMessage;

  bool get isSynced => type == LyricsResultType.synced;
  bool get isPlain => type == LyricsResultType.plain;
  bool get hasLyrics => lines.isNotEmpty;
}

// ════════════════════════════════════════════════════════════════════════════
// LyricsService
// ════════════════════════════════════════════════════════════════════════════

class LyricsService {
  static const _baseUrl = 'https://lrclib.net/api';
  static const _timeout = Duration(seconds: 5);

  // ── Cache dir lazy init ────────────────────────────────────────────────────

  Directory? _cacheDir;

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationCacheDirectory();
    final dir = Directory('${appDir.path}/lyrics_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  /// Cache key dựa trên title + artist (lowercase, normalized).
  String _cacheKey(String title, String artist) {
    final clean = (s) => s.toLowerCase().replaceAll(RegExp(r'[^\w]'), '_');
    return '${clean(artist)}__${clean(title)}';
  }

  Future<File> _cacheFile(String title, String artist) async {
    final dir = await _getCacheDir();
    return File('${dir.path}/${_cacheKey(title, artist)}.json');
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetch lyrics cho [title] + [artist].
  /// Thứ tự: file cache → LRCLIB API → notFound.
  Future<LyricsResult> fetchLyrics({
    required String title,
    required String artist,
    int? durationSeconds,
  }) async {
    debugPrint('🎵 [Lyrics] Fetching: "$title" - "$artist" (duration: ${durationSeconds}s)');

    // 1. Check cache
    try {
      final file = await _cacheFile(title, artist);
      if (await file.exists()) {
        debugPrint('📦 [Lyrics] Cache hit: ${file.path}');
        final cached = await _loadFromCache(file);
        if (cached != null) {
          debugPrint('✅ [Lyrics] Loaded from cache: ${cached.type} (${cached.lines.length} lines)');
          return cached;
        }
      } else {
        debugPrint('📭 [Lyrics] No cache for this song');
      }
    } catch (e) {
      debugPrint('⚠️ [Lyrics] Cache read error: $e');
    }

    // 2. Fetch từ LRCLIB
    try {
      final result = await _fetchFromApi(
        title: title,
        artist: artist,
        durationSeconds: durationSeconds,
      );

      debugPrint('🔍 [Lyrics] API result: ${result.type} (${result.lines.length} lines)');

      if (result.hasLyrics) {
        try {
          await _writeCache(title, artist, result);
          debugPrint('💾 [Lyrics] Cached successfully');
        } catch (e) {
          debugPrint('⚠️ [Lyrics] Cache write error: $e');
        }
      }

      return result;
    } catch (e, stack) {
      debugPrint('❌ [Lyrics] Fetch error: $e\n$stack');
      return LyricsResult.error(e.toString());
    }
  }

  /// Xóa cache của một bài.
  Future<void> clearCache(String title, String artist) async {
    try {
      final file = await _cacheFile(title, artist);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Xóa toàn bộ lyrics cache.
  Future<void> clearAllCache() async {
    try {
      final dir = await _getCacheDir();
      if (await dir.exists()) await dir.delete(recursive: true);
      _cacheDir = null;
    } catch (_) {}
  }

  // ── LRCLIB API ─────────────────────────────────────────────────────────────

  Future<LyricsResult> _fetchFromApi({
    required String title,
    required String artist,
    int? durationSeconds,
  }) async {
    final params = {
      'track_name': title,
      'artist_name': artist,
      if (durationSeconds != null) 'duration': durationSeconds.toString(),
    };

    final uri = Uri.parse('$_baseUrl/get').replace(queryParameters: params);
    debugPrint('🌐 [Lyrics] GET $uri');

    final response = await http
        .get(uri, headers: {'User-Agent': 'MuziczApp/1.0'})
        .timeout(_timeout);

    debugPrint('📡 [Lyrics] HTTP ${response.statusCode}');
    debugPrint('📄 [Lyrics] Response body: ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');

    if (response.statusCode == 404) {
      debugPrint('🔴 [Lyrics] 404 - Not found on LRCLIB');
      return LyricsResult.notFound();
    }

    if (response.statusCode != 200) {
      debugPrint('🔴 [Lyrics] Non-200 status: ${response.statusCode}');
      return LyricsResult.error('HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    debugPrint('🔑 [Lyrics] JSON keys: ${json.keys.toList()}');
    debugPrint('   syncedLyrics: ${json['syncedLyrics'] != null ? "có (${(json['syncedLyrics'] as String).length} chars)" : "null"}');
    debugPrint('   plainLyrics:  ${json['plainLyrics']  != null ? "có (${(json['plainLyrics']  as String).length} chars)" : "null"}');

    return _parseApiResponse(json);
  }

  LyricsResult _parseApiResponse(Map<String, dynamic> json) {
    final syncedRaw = json['syncedLyrics'] as String?;
    final plainRaw = json['plainLyrics'] as String?;

    if (syncedRaw != null && syncedRaw.trim().isNotEmpty) {
      final lines = parseLrc(syncedRaw);
      debugPrint('🎼 [Lyrics] Parsed synced: ${lines.length} lines');
      if (lines.isNotEmpty) return LyricsResult.synced(lines);
      debugPrint('⚠️ [Lyrics] parseLrc returned 0 lines — raw sample:\n${syncedRaw.substring(0, syncedRaw.length.clamp(0, 200))}');
    }

    if (plainRaw != null && plainRaw.trim().isNotEmpty) {
      final lines = _parsePlain(plainRaw);
      debugPrint('📝 [Lyrics] Parsed plain: ${lines.length} lines');
      if (lines.isNotEmpty) return LyricsResult.plain(lines);
    }

    debugPrint('🔴 [Lyrics] Both synced and plain empty/null → notFound');
    return LyricsResult.notFound();
  }

  // ── LRC parser ─────────────────────────────────────────────────────────────

  /// Parse chuỗi LRC thành danh sách [LyricLine] có timestamp.
  ///
  /// Format LRC chuẩn: `[mm:ss.xx] text`
  /// Bỏ qua metadata tags (ti:, ar:, al:, v.v.)
  static List<LyricLine> parseLrc(String lrc) {
    final lines = <LyricLine>[];
    final lineRegex = RegExp(r'^\[(\d{1,3}):(\d{2})\.(\d{1,3})\](.*)$');

    for (final rawLine in lrc.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final match = lineRegex.firstMatch(trimmed);
      if (match == null) continue;

      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      // Centiseconds có thể 2 hoặc 3 chữ số
      final csRaw = match.group(3)!;
      final cs = csRaw.length == 3
          ? int.parse(csRaw)
          : int.parse(csRaw) * 10;

      final time = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: cs * 10 ~/ 10, // normalize to ms
      );

      final text = match.group(4)!.trim();
      // Bỏ dòng trắng (instrumental break) vẫn giữ để giữ nhịp scroll
      lines.add(LyricLine(text: text, time: time));
    }

    lines.sort((a, b) => a.time!.compareTo(b.time!));
    return lines;
  }

  // ── Plain lyrics parser ────────────────────────────────────────────────────

  List<LyricLine> _parsePlain(String plain) {
    return plain
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => LyricLine(text: l))
        .toList();
  }

  // ── File cache ─────────────────────────────────────────────────────────────

  Future<LyricsResult?> _loadFromCache(File file) async {
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;

    final typeStr = json['type'] as String?;
    final rawLines = json['lines'] as List<dynamic>? ?? [];

    final lines = rawLines.map((e) {
      final map = e as Map<String, dynamic>;
      final timeMs = map['timeMs'] as int?;
      final text = map['text'] as String? ?? '';
      return LyricLine(
        text: text,
        time: timeMs != null ? Duration(milliseconds: timeMs) : null,
      );
    }).toList();

    if (lines.isEmpty) return LyricsResult.notFound();

    return switch (typeStr) {
      'synced' => LyricsResult.synced(lines),
      'plain'  => LyricsResult.plain(lines),
      _        => null,
    };
  }

  Future<void> _writeCache(
      String title,
      String artist,
      LyricsResult result,
      ) async {
    final file = await _cacheFile(title, artist);
    final json = {
      'type': result.isSynced ? 'synced' : 'plain',
      'lines': result.lines
          .map((l) => {
        'text': l.text,
        if (l.time != null) 'timeMs': l.time!.inMilliseconds,
      })
          .toList(),
    };
    await file.writeAsString(jsonEncode(json));
  }
}