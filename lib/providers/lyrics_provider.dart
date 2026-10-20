import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lyric_line.dart';
import '../models/song_item.dart';
import '../services/lyrics_service.dart';

enum LyricsStatus {
  idle,
  loading,
  synced,
  plain,
  instrumental,
  notFound,
  error,
}

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
  final int? songId;
  bool get isLoading => status == LyricsStatus.loading;
  bool get hasLyrics =>
      status == LyricsStatus.synced || status == LyricsStatus.plain;
  bool get isSynced => status == LyricsStatus.synced;
  LyricsState copyWith({
    LyricsStatus? status,
    List<LyricLine>? lines,
    int? currentIndex,
    int? songId,
  }) => LyricsState(
    status: status ?? this.status,
    lines: lines ?? this.lines,
    currentIndex: currentIndex ?? this.currentIndex,
    songId: songId ?? this.songId,
  );
  static const idle = LyricsState(status: LyricsStatus.idle);
}

class LyricsProvider extends ChangeNotifier {
  LyricsProvider({LyricsService? service})
    : _service = service ?? LyricsService();
  final LyricsService _service;
  LyricsState _state = LyricsState.idle;
  LyricsState get state => _state;
  LyricsStatus get status => _state.status;
  List<LyricLine> get lines => _state.lines;
  int get currentIndex => _state.currentIndex;
  bool get hasLyrics => _state.hasLyrics;
  bool get isSynced => _state.isSynced;
  bool get isLoading => _state.isLoading;
  LyricsResult? document;
  SongItem? song;
  String? message;
  int _generation = 0;
  bool _disposed = false;
  Duration position = Duration.zero;
  int currentWord = -1;
  int offsetMs = 0;
  LyricsSourcePreference sourcePreference =
      LyricsSourcePreference.embeddedFirst;
  double fontSize = 28;
  String alignment = 'left';
  bool get center => alignment == 'center';
  bool animated = false;
  double blurStrength = 2.5;
  bool blur = true, translation = true, romanization = true, immersive = false;
  SharedPreferences? _prefs;
  Future<void>? _initializing;

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    sourcePreference = LyricsSourcePreference.values.firstWhere(
      (p) => p.name == prefs.getString('lyrics_source'),
      orElse: () => LyricsSourcePreference.embeddedFirst,
    );
    fontSize = (prefs.getDouble('lyrics_font') ?? 28).clamp(18, 42);
    alignment =
        prefs.getString('lyrics_alignment') ??
        ((prefs.getBool('lyrics_center') ?? false) ? 'center' : 'left');
    animated = prefs.getBool('lyrics_animated') ?? false;
    blurStrength = (prefs.getDouble('lyrics_blur_strength') ?? 2.5).clamp(
      0,
      10,
    );
    blur = prefs.getBool('lyrics_blur') ?? true;
    translation = prefs.getBool('lyrics_translation') ?? true;
    romanization = prefs.getBool('lyrics_romanization') ?? true;
    immersive = prefs.getBool('lyrics_immersive') ?? false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadLyrics(SongItem value) => load(value);
  Future<void> load(SongItem value, {bool refresh = false}) async {
    if (!refresh &&
        song != null &&
        LyricsService.key(song!) == LyricsService.key(value) &&
        (isLoading || hasLyrics || status == LyricsStatus.instrumental)) {
      return;
    }
    final generation = ++_generation;
    song = value;
    document = null;
    message = null;
    currentWord = -1;
    position = Duration.zero;
    _state = LyricsState(status: LyricsStatus.loading, songId: value.id);
    _notify();
    try {
      await initialize();
      if (_disposed || generation != _generation) return;
      offsetMs =
          _prefs?.getInt('lyrics_offset_${LyricsService.key(value)}') ?? 0;
      final result = await _service.load(
        value,
        sourcePreference,
        refresh: refresh,
      );
      if (_disposed || generation != _generation) return;
      _apply(value, result);
      if (result.hasLyrics || result.type == LyricsResultType.instrumental) {
        try {
          await _service.save(value, result);
        } catch (_) {
          if (generation == _generation) {
            message = 'Lời đã tải nhưng chưa lưu được offline.';
            _notify();
          }
        }
      }
    } catch (e) {
      if (!_disposed && generation == _generation) {
        _apply(
          value,
          LyricsResult.error('Không đọc được lời. Hãy thử lại hoặc nhập file.'),
        );
      }
    }
  }

  void _apply(SongItem value, LyricsResult result) {
    document = result;
    message = result.message;
    currentWord = -1;
    _state = LyricsState(
      status: switch (result.type) {
        LyricsResultType.synced => LyricsStatus.synced,
        LyricsResultType.plain => LyricsStatus.plain,
        LyricsResultType.instrumental => LyricsStatus.instrumental,
        LyricsResultType.notFound => LyricsStatus.notFound,
        LyricsResultType.error => LyricsStatus.error,
      },
      lines: result.lines,
      songId: value.id,
    );
    updatePosition(position);
    _notify();
  }

  Future<List<LyricsCandidate>> search(
    SongItem target,
    String title,
    String artist,
  ) => _service.search(title, artist, song: target);

  /// Target is captured before opening a picker/search: never assign to a later song.
  Future<void> assign(SongItem target, LyricsResult result) async {
    final isCurrent =
        song != null && LyricsService.key(song!) == LyricsService.key(target);
    final generation = isCurrent ? ++_generation : _generation;
    await _service.save(target, result);
    if (!_disposed &&
        generation == _generation &&
        song != null &&
        LyricsService.key(song!) == LyricsService.key(target)) {
      _apply(target, result);
    }
  }

  Future<void> reset(SongItem target) async {
    final isCurrent =
        song != null && LyricsService.key(song!) == LyricsService.key(target);
    final generation = isCurrent ? ++_generation : _generation;
    await _service.remove(target);
    if (!_disposed &&
        generation == _generation &&
        song != null &&
        LyricsService.key(song!) == LyricsService.key(target)) {
      document = null;
      message = null;
      _state = LyricsState(status: LyricsStatus.notFound, songId: target.id);
      _notify();
    }
  }

  Future<int> scanSidecars(
    List<SongItem> songs, {
    void Function(int, int)? progress,
  }) async {
    var count = 0;
    for (var i = 0; i < songs.length; i++) {
      if (_disposed) break;
      try {
        if (await _service.stored(songs[i]) == null) {
          final result = await _service.findSidecar(songs[i]);
          if (result != null) {
            await assign(songs[i], result);
            count++;
          }
        }
      } catch (_) {
        /* An unreadable file does not abort a library scan. */
      }
      progress?.call(i + 1, songs.length);
    }
    return count;
  }

  Future<void> setOffset(int value) async {
    offsetMs = value.clamp(-60000, 60000);
    final savedOffset = offsetMs;
    final target = song;
    updatePosition(position);
    _notify();
    if (target != null) {
      await initialize();
      await _prefs!.setInt(
        'lyrics_offset_${LyricsService.key(target)}',
        savedOffset,
      );
    }
  }

  Future<void> preferences({
    LyricsSourcePreference? source,
    double? size,
    bool? centered,
    String? textAlignment,
    bool? animatedLines,
    double? blurAmount,
    bool? blurred,
    bool? translations,
    bool? romanized,
    bool? immersiveMode,
  }) async {
    await initialize();
    sourcePreference = source ?? sourcePreference;
    fontSize = (size ?? fontSize).clamp(18, 42);
    alignment =
        textAlignment ??
        (centered == null
            ? alignment
            : centered
            ? 'center'
            : 'left');
    animated = animatedLines ?? animated;
    blurStrength = (blurAmount ?? blurStrength).clamp(0, 10);
    blur = blurred ?? blur;
    translation = translations ?? translation;
    romanization = romanized ?? romanization;
    immersive = immersiveMode ?? immersive;
    _notify();
    await Future.wait([
      _prefs!.setString('lyrics_source', sourcePreference.name),
      _prefs!.setDouble('lyrics_font', fontSize),
      _prefs!.setBool('lyrics_center', center),
      _prefs!.setString('lyrics_alignment', alignment),
      _prefs!.setBool('lyrics_animated', animated),
      _prefs!.setDouble('lyrics_blur_strength', blurStrength),
      _prefs!.setBool('lyrics_blur', blur),
      _prefs!.setBool('lyrics_translation', translation),
      _prefs!.setBool('lyrics_romanization', romanization),
      _prefs!.setBool('lyrics_immersive', immersive),
    ]);
  }

  Duration seekPosition(LyricLine line) => Duration(
    milliseconds: ((line.time?.inMilliseconds ?? 0) - offsetMs).clamp(
      0,
      song?.duration ?? 1 << 31,
    ),
  );
  void updatePosition(Duration value) {
    position = value;
    if (!isSynced || lines.isEmpty) return;
    final effective = value + Duration(milliseconds: offsetMs);
    var low = 0, high = lines.length - 1, index = -1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if ((lines[mid].time ?? Duration.zero) <= effective) {
        index = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    var word = -1;
    if (index >= 0) {
      for (var i = 0; i < lines[index].words.length; i++) {
        if (lines[index].words[i].start <= effective) {
          word = i;
        } else {
          break;
        }
      }
    }
    if (index == currentIndex && word == currentWord) return;
    currentWord = word;
    _state = _state.copyWith(currentIndex: index);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _service.dispose();
    super.dispose();
  }
}
