import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/lyric_line.dart';
import '../providers/lyrics_provider.dart';
import '../providers/player_provider.dart';
import '../services/audio_handler.dart';
import '../theme/app_colors_data.dart';
import '../widgets/now_playing/lyrics_tools.dart';
import '../widgets/now_playing/lyrics_ai_tools.dart';

/// PixelPlayer-style full-page lyrics: track header, expressive lines and playback dock.
class LyricsScreen extends StatefulWidget {
  const LyricsScreen({super.key});
  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  late final PlayerProvider _player;
  late final LyricsProvider _lyrics;
  StreamSubscription<PositionData>? _position;
  final _scroll = ScrollController();
  final _anchors = <int, GlobalKey>{};
  int? _songId;
  int _lastLine = -1;
  bool _following = true, _plain = false, _hidden = false, _keepAwake = false;
  Timer? _immersiveTimer;
  PositionData? _data;
  @override
  void initState() {
    super.initState();
    _player = context.read<PlayerProvider>();
    _lyrics = context.read<LyricsProvider>();
    _player.addListener(_songChanged);
    _lyrics.addListener(_lyricsChanged);
    _position = _player.positionDataStream.listen((data) {
      if (!mounted) return;
      _data = data;
      _lyrics.updatePosition(data.position);
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _songChanged();
        _interact();
      }
    });
  }

  void _songChanged() {
    final song = _player.currentSong;
    if (song != null && song.id != _songId) {
      _songId = song.id;
      _lastLine = -1;
      _anchors.clear();
      _plain = false;
      _following = true;
      _data = null;
      _lyrics.loadLyrics(song);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
    if (mounted) setState(() {});
  }

  void _lyricsChanged() {
    if (!mounted) return;
    if (_lyrics.currentIndex != _lastLine && _following && !_plain) {
      _lastLine = _lyrics.currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
    }
    if (!_lyrics.immersive && _hidden) _hidden = false;
    setState(() {});
  }

  void _follow() {
    if (!mounted || !_following || _plain) return;
    final anchor = _anchors[_lyrics.currentIndex]?.currentContext;
    if (anchor != null) {
      Scrollable.ensureVisible(
        anchor,
        alignment: .42,
        duration:
            MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _interact() {
    if (!mounted) return;
    _immersiveTimer?.cancel();
    if (_hidden && mounted) setState(() => _hidden = false);
    _immersiveTimer = Timer(const Duration(seconds: 5), () {
      if (mounted &&
          _lyrics.immersive &&
          _lyrics.hasLyrics &&
          _player.isPlaying) {
        setState(() => _hidden = true);
      }
    });
  }

  Future<void> _awake(bool enabled) async {
    try {
      await const MethodChannel(
        'muzicz/lyrics',
      ).invokeMethod<void>('keepScreenOn', enabled);
      if (mounted) setState(() => _keepAwake = enabled);
    } on MissingPluginException {
      /* Only Android needs the native window flag. */
    } on PlatformException catch (e) {
      if (mounted) lyricsMessage(context, e.message ?? e.code);
    }
  }

  @override
  void dispose() {
    _player.removeListener(_songChanged);
    _lyrics.removeListener(_lyricsChanged);
    _position?.cancel();
    _immersiveTimer?.cancel();
    _scroll.dispose();
    if (_keepAwake) _awake(false);
    super.dispose();
  }

  Future<void> _action(String action) async {
    _interact();
    final song = _player.currentSong;
    if (song == null) return;
    switch (action) {
      case 'search':
        await showLyricsSearch(context, song);
      case 'aiSettings':
        await showLyricsAiSettings(context);
      case 'translate':
        await translateLyrics(context, song);
      case 'import':
        await importLyrics(context, song);
      case 'edit':
        await editLyrics(context, song);
      case 'export':
        await exportLyrics(context);
      case 'plainExport':
        await exportLyrics(context, plain: true);
      case 'original':
        await exportLyrics(context, original: true);
      case 'copy':
        await Clipboard.setData(
          ClipboardData(text: _lyrics.lines.map((l) => l.text).join('\n')),
        );
        if (mounted) lyricsMessage(context, 'Đã sao chép lời');
      case 'plain':
        setState(() {
          _plain = !_plain;
          _lastLine = -1;
        });
      case 'offset':
        await showLyricsOffset(context);
      case 'preferences':
        await showLyricsPreferences(context);
      case 'awake':
        await _awake(!_keepAwake);
      case 'refresh':
        await _lyrics.load(song, refresh: true);
      case 'reset':
        final accepted = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Xóa lời đã lưu?'),
                content: const Text(
                  'Chỉ xóa bản gán trong Muzicz. File nhạc và file lời gốc được giữ nguyên.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Xóa'),
                  ),
                ],
              ),
        );
        if (accepted == true) {
          try {
            await _lyrics.reset(song);
          } catch (e) {
            if (mounted) lyricsMessage(context, e);
          }
        }
    }
    _interact();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final song = _player.currentSong;
    return Scaffold(
      backgroundColor: Color.lerp(
        c.background,
        c.primary,
        c.isDark ? .12 : .06,
      ),
      body: SafeArea(
        child: Listener(
          onPointerDown: (_) => _interact(),
          child: Column(
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child:
                    _hidden
                        ? const SizedBox.shrink()
                        : Row(
                          children: [
                            IconButton(
                              tooltip: 'Đóng lời bài hát',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                            ),
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  song?.title ?? 'Lời bài hát',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  song?.artist ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Tùy chọn lời bài hát',
                              onSelected: _action,
                              itemBuilder:
                                  (_) => [
                                    const PopupMenuItem(
                                      value: 'search',
                                      child: Text('Tìm / chọn lời khác'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'import',
                                      child: Text('Nhập file lời'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Dán / chỉnh sửa lời'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'refresh',
                                      child: Text('Tìm lại theo nguồn ưu tiên'),
                                    ),
                                    if (_lyrics.hasLyrics) ...[
                                      const PopupMenuItem(
                                        value: 'export',
                                        child: Text('Xuất LRC / lời đồng bộ'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'plainExport',
                                        child: Text('Xuất văn bản TXT'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'original',
                                        child: Text(
                                          'Xuất bản gốc (giữ bản dịch)',
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'copy',
                                        child: Text('Sao chép lời'),
                                      ),
                                      if (_lyrics.isSynced)
                                        PopupMenuItem(
                                          value: 'plain',
                                          child: Text(
                                            _plain
                                                ? 'Xem đồng bộ'
                                                : 'Xem văn bản',
                                          ),
                                        ),
                                      const PopupMenuItem(
                                        value: 'reset',
                                        child: Text('Xóa lời đã lưu'),
                                      ),
                                    ],
                                    PopupMenuItem(
                                      value: 'awake',
                                      child: Text(
                                        _keepAwake
                                            ? 'Cho phép tắt màn hình'
                                            : 'Giữ màn hình sáng',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'aiSettings',
                                      child: Text('Cấu hình dịch AI'),
                                    ),
                                    if (_lyrics.hasLyrics)
                                      const PopupMenuItem(
                                        value: 'translate',
                                        child: Text('Dịch lời bằng AI'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'preferences',
                                      child: Text('Giao diện và nguồn lời'),
                                    ),
                                  ],
                            ),
                          ],
                        ),
              ),
              Expanded(
                child: _lyrics.hasLyrics ? _list(context) : _empty(context),
              ),
              if (!_following && _lyrics.isSynced && !_plain)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _following = true);
                    _follow();
                  },
                  icon: const Icon(Icons.my_location),
                  label: const Text('Theo dõi lời đang hát'),
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: _hidden ? const SizedBox.shrink() : _controls(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final song = _player.currentSong;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_lyrics.isLoading)
              const CircularProgressIndicator()
            else
              Icon(
                _lyrics.status == LyricsStatus.instrumental
                    ? Icons.music_note
                    : _lyrics.status == LyricsStatus.error
                    ? Icons.wifi_off
                    : Icons.lyrics_outlined,
                size: 64,
              ),
            const SizedBox(height: 20),
            Text(
              _lyrics.isLoading
                  ? 'Đang tìm lời bài hát…'
                  : _lyrics.status == LyricsStatus.instrumental
                  ? 'Bản nhạc không lời'
                  : _lyrics.message ?? 'Chưa có lời bài hát',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (song != null) ...[
              FilledButton.icon(
                onPressed: () => showLyricsSearch(context, song),
                icon: const Icon(Icons.search),
                label: const Text('Tìm lời bài hát'),
              ),
              OutlinedButton.icon(
                onPressed: () => importLyrics(context, song),
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Nhập LRC / TTML / TXT'),
              ),
              TextButton(
                onPressed: () => editLyrics(context, song),
                child: const Text('Dán lời từ clipboard'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final c = context.appColors;
    return LayoutBuilder(
      builder:
          (context, constraints) => NotificationListener<ScrollNotification>(
            onNotification: (event) {
              if (event is ScrollStartNotification &&
                  event.dragDetails != null) {
                setState(() => _following = false);
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                28,
                constraints.maxHeight * .35,
                28,
                constraints.maxHeight * .4,
              ),
              child: Column(
                crossAxisAlignment:
                    _lyrics.center
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _lyrics.lines.length; i++)
                    _line(context, _lyrics.lines[i], i),
                  const SizedBox(height: 30),
                  Text(
                    _lyrics.document?.source ?? '',
                    style: TextStyle(color: c.textTertiary, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  if (_lyrics.message != null)
                    Text(_lyrics.message!, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
    );
  }

  Widget _line(BuildContext context, LyricLine line, int index) {
    final c = context.appColors;
    final active = !_plain && _lyrics.isSynced && index == _lyrics.currentIndex;
    final timed = !_plain && _lyrics.isSynced;
    final color =
        !timed || active ? c.textPrimary : c.textPrimary.withValues(alpha: .35);
    final style = TextStyle(
      fontSize: _lyrics.fontSize,
      fontWeight: FontWeight.w700,
      height: 1.4,
      color: color,
    );
    final words = line.words;
    final text =
        words.isEmpty || !active
            ? Text(
              line.text.isEmpty ? '•••' : line.text,
              textAlign: _lyrics.center ? TextAlign.center : TextAlign.left,
              style: style,
            )
            : Text.rich(
              TextSpan(
                children: [
                  for (var i = 0; i < words.length; i++)
                    TextSpan(
                      text: words[i].text,
                      style: style.copyWith(
                        color:
                            i <= _lyrics.currentWord
                                ? c.primary
                                : c.textPrimary.withValues(alpha: .4),
                      ),
                    ),
                ],
              ),
              textAlign: _lyrics.center ? TextAlign.center : TextAlign.left,
            );
    return Padding(
      key: _anchors.putIfAbsent(index, () => GlobalKey()),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            line.time == null
                ? null
                : () {
                  _player.seekTo(_lyrics.seekPosition(line));
                  setState(() => _following = true);
                },
        child: AnimatedScale(
          scale: active ? 1.025 : 1,
          alignment: _lyrics.center ? Alignment.center : Alignment.centerLeft,
          duration:
              MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
          child: ImageFiltered(
            enabled:
                timed &&
                _lyrics.blur &&
                !active &&
                (index - _lyrics.currentIndex).abs() <= 5,
            imageFilter: ImageFilter.blur(sigmaX: 1.1, sigmaY: 1.1),
            child: Column(
              crossAxisAlignment:
                  _lyrics.center
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
              children: [
                text,
                if (_lyrics.romanization && line.romanization != null)
                  Text(
                    line.romanization!,
                    style: style.copyWith(
                      fontSize: _lyrics.fontSize * .7,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                if (_lyrics.translation && line.translation != null)
                  Text(
                    line.translation!,
                    style: style.copyWith(
                      fontSize: _lyrics.fontSize * .7,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context) {
    final duration =
        _data?.duration.inMilliseconds ?? _player.currentSong?.duration ?? 0;
    final position = (_data?.position.inMilliseconds ?? 0).clamp(
      0,
      duration > 0 ? duration : 0,
    );
    String stamp(int ms) =>
        '${ms ~/ 60000}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: position.toDouble(),
            max: duration > 0 ? duration.toDouble() : 1,
            onChanged:
                duration <= 0
                    ? null
                    : (v) => _player.seekTo(Duration(milliseconds: v.round())),
            semanticFormatterCallback: (v) => stamp(v.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(stamp(position)), Text(stamp(duration))],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Đồng bộ thời gian',
                onPressed:
                    _lyrics.isSynced ? () => showLyricsOffset(context) : null,
                icon: const Icon(Icons.sync),
              ),
              IconButton(
                tooltip: 'Bài trước',
                onPressed: _player.skipToPrevious,
                icon: const Icon(Icons.skip_previous_rounded, size: 32),
              ),
              IconButton.filled(
                tooltip: _player.isPlaying ? 'Tạm dừng' : 'Phát',
                onPressed: _player.playPause,
                icon: Icon(
                  _player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 36,
                ),
              ),
              IconButton(
                tooltip: 'Bài tiếp',
                onPressed: _player.skipToNext,
                icon: const Icon(Icons.skip_next_rounded, size: 32),
              ),
              IconButton(
                tooltip: 'Giao diện lời',
                onPressed: () => showLyricsPreferences(context),
                icon: const Icon(Icons.text_fields),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
