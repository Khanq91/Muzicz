import 'package:flutter/foundation.dart';
import '../models/lyric_line.dart';
import '../models/song_item.dart';
import '../services/lyrics_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// LyricsState
// ════════════════════════════════════════════════════════════════════════════

enum LyricsStatus { idle, loading, synced, plain, notFound, error }

class LyricsState {
  const LyricsState({
    required this.status,
    this.lines = const [],
    this.currentIndex = -1,
    this.songId,
  });

  final LyricsStatus status;
  final List<LyricLine> lines;
  final int currentIndex;
  final int? songId; // track để tránh stale update

  bool get isLoading => status == LyricsStatus.loading;
  bool get hasLyrics =>
      status == LyricsStatus.synced || status == LyricsStatus.plain;
  bool get isSynced => status == LyricsStatus.synced;

  LyricsState copyWith({
    LyricsStatus? status,
    List<LyricLine>? lines,
    int? currentIndex,
    int? songId,
  }) =>
      LyricsState(
        status: status ?? this.status,
        lines: lines ?? this.lines,
        currentIndex: currentIndex ?? this.currentIndex,
        songId: songId ?? this.songId,
      );

  static const idle = LyricsState(status: LyricsStatus.idle);
}

// ════════════════════════════════════════════════════════════════════════════
// LyricsProvider
// ════════════════════════════════════════════════════════════════════════════

class LyricsProvider extends ChangeNotifier {
  LyricsProvider() : _service = LyricsService();

  final LyricsService _service;

  LyricsState _state = LyricsState.idle;
  LyricsState get state => _state;

  // Shortcut getters dùng trong UI
  LyricsStatus get status => _state.status;
  List<LyricLine> get lines => _state.lines;
  int get currentIndex => _state.currentIndex;
  bool get hasLyrics => _state.hasLyrics;
  bool get isSynced => _state.isSynced;
  bool get isLoading => _state.isLoading;

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<void> loadLyrics(SongItem song) async {
    // Đã load bài này rồi thì skip
    if (_state.songId == song.id && _state.hasLyrics) return;
    if (_state.songId == song.id && _state.isLoading) return;

    _state = LyricsState(
      status: LyricsStatus.loading,
      songId: song.id,
    );
    notifyListeners();

    final durationSeconds =
    song.duration > 0 ? (song.duration / 1000).round() : null;

    final result = await _service.fetchLyrics(
      title: song.title,
      artist: song.artist,
      durationSeconds: durationSeconds,
    );

    // Guard: bài đã đổi trong lúc fetch
    if (_state.songId != song.id) return;

    _state = switch (result.type) {
      LyricsResultType.synced => LyricsState(
        status: LyricsStatus.synced,
        lines: result.lines,
        songId: song.id,
      ),
      LyricsResultType.plain => LyricsState(
        status: LyricsStatus.plain,
        lines: result.lines,
        songId: song.id,
      ),
      LyricsResultType.notFound => LyricsState(
        status: LyricsStatus.notFound,
        songId: song.id,
      ),
      LyricsResultType.error => LyricsState(
        status: LyricsStatus.error,
        songId: song.id,
      ),
    };

    notifyListeners();
  }

  // ── Sync position → highlight current line ─────────────────────────────────

  /// Gọi từ UI mỗi khi position stream tick (với throttle).
  /// Tìm dòng active dựa trên [position] và notify nếu thay đổi.
  void updatePosition(Duration position) {
    if (!_state.isSynced || _state.lines.isEmpty) return;

    final newIndex = _findCurrentIndex(position);
    if (newIndex == _state.currentIndex) return;

    _state = _state.copyWith(currentIndex: newIndex);
    notifyListeners();
  }

  int _findCurrentIndex(Duration position) {
    final lines = _state.lines;
    int result = -1;

    for (int i = 0; i < lines.length; i++) {
      final t = lines[i].time;
      if (t == null) continue;
      if (t <= position) {
        result = i;
      } else {
        break;
      }
    }

    return result;
  }

  // ── Reset khi đổi bài ─────────────────────────────────────────────────────

  void reset() {
    _state = LyricsState.idle;
    notifyListeners();
  }

  // ── Cache utils ────────────────────────────────────────────────────────────

  Future<void> clearCacheForCurrent() async {
    final id = _state.songId;
    if (id == null) return;
    // Cần song object để clear — nếu caller có thể pass vào thì tốt hơn.
    // Đây chỉ reset state, cache file tự expire theo logic bên LyricsService.
    reset();
  }

  Future<void> clearAllCache() => _service.clearAllCache();
}