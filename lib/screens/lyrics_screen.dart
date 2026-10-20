import 'dart:async';
import 'package:on_audio_query/on_audio_query.dart';
import '../widgets/now_playing/pixel_lyric_line.dart';
import '../widgets/now_playing/lyrics_seek_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

class _LyricsScreenState extends State<LyricsScreen>
    with SingleTickerProviderStateMixin {
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
  double? _seekPreview;
  bool _showSync = false;
  double _swipeDistance = 0;
  late final AnimationController _vinyl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
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
      if (_seekPreview == null) _lyrics.updatePosition(data.position);
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
    if (mounted) {
      if (_player.isPlaying && !MediaQuery.disableAnimationsOf(context)) {
        if (!_vinyl.isAnimating) _vinyl.repeat();
      } else {
        _vinyl.stop();
      }
      setState(() {});
    }
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
      final object = anchor.findRenderObject();
      if (object == null || !_scroll.hasClients) return;
      final viewport = RenderAbstractViewport.of(object);
      final target = (viewport.getOffsetToReveal(object, .5).offset + 32).clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      );
      final index = _lyrics.currentIndex;
      final current = _lyrics.lines[index].time ?? Duration.zero;
      final next =
          index + 1 < _lyrics.lines.length
              ? _lyrics.lines[index + 1].time ??
                  current + const Duration(seconds: 1)
              : current + const Duration(seconds: 1);
      final milliseconds =
          _seekPreview != null
              ? 110
              : _lyrics.animated
              ? (next - current).inMilliseconds.clamp(250, 2000)
              : 450;
      _scroll.animateTo(
        target,
        duration:
            MediaQuery.disableAnimationsOf(context)
                ? const Duration(microseconds: 1)
                : Duration(milliseconds: milliseconds),
        curve: Curves.fastOutSlowIn,
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
    _vinyl.dispose();
    if (_keepAwake) _awake(false);
    super.dispose();
  }

  Future<void> _action(String action) async {
    _interact();
    _immersiveTimer?.cancel();
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
        setState(() => _showSync = !_showSync);
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

  Duration get _motion =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragStart: (_) {
            _swipeDistance = 0;
            _interact();
          },
          onHorizontalDragUpdate:
              (details) => _swipeDistance += details.delta.dx,
          onHorizontalDragEnd: (_) {
            if (_swipeDistance < -100) _player.skipToNext();
            if (_swipeDistance > 100) _player.skipToPrevious();
            _swipeDistance = 0;
          },
          child: Listener(
            onPointerDown: (_) => _interact(),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child:
                            _lyrics.hasLyrics
                                ? _list(context)
                                : _empty(context),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 130,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  c.background,
                                  c.background.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 80,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  c.background.withValues(alpha: 0),
                                  c.background,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        left: 18,
                        right: 18,
                        child: _header(context),
                      ),
                    ],
                  ),
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
                  duration: _motion,
                  curve: Curves.fastOutSlowIn,
                  alignment: Alignment.topCenter,
                  child: _hidden ? const SizedBox.shrink() : _controls(context),
                ),
                if (_hidden)
                  TextButton.icon(
                    onPressed: _interact,
                    icon: const Icon(Icons.touch_app_outlined),
                    label: const Text('Hiện điều khiển'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final c = context.appColors, song = _player.currentSong;
    return AnimatedSwitcher(
      duration: _motion,
      transitionBuilder:
          (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: .9, end: 1.0).animate(animation),
              child: child,
            ),
          ),
      child: Material(
        key: ValueKey(song?.id),
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
          child: Row(
            children: [
              RotationTransition(
                turns: _vinyl,
                child: ClipOval(
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child:
                        song == null
                            ? const Icon(Icons.album)
                            : QueryArtworkWidget(
                              id: song.albumId,
                              type: ArtworkType.ALBUM,
                              artworkBorder: BorderRadius.zero,
                              keepOldArtwork: true,
                              nullArtworkWidget: Icon(
                                Icons.album,
                                size: 48,
                                color: c.primary,
                              ),
                            ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song?.title ?? 'Lời bài hát',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      song?.artist ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _player.isPlaying ? Icons.graphic_eq : Icons.more_horiz,
                size: 18,
                color: c.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _more() async {
    _interact();
    _immersiveTimer?.cancel();
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appColors.surface,
      showDragHandle: true,
      builder:
          (context) => FractionallySizedBox(
            heightFactor: .78,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(
                  'Tùy chọn lời bài hát',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                for (final item in <(String, IconData, String)>[
                  ('search', Icons.search, 'Tìm / chọn lời khác'),
                  ('import', Icons.file_open_outlined, 'Nhập file lời'),
                  ('edit', Icons.edit_outlined, 'Dán / chỉnh sửa lời'),
                  ('refresh', Icons.refresh, 'Tìm lại theo nguồn ưu tiên'),
                  if (_lyrics.isSynced)
                    ('offset', Icons.sync, 'Đồng bộ thời gian'),
                  if (_lyrics.hasLyrics) ...[
                    ('export', Icons.save_alt, 'Xuất LRC / lời đồng bộ'),
                    ('plainExport', Icons.notes, 'Xuất văn bản TXT'),
                    ('original', Icons.download, 'Xuất bản gốc (giữ bản dịch)'),
                    ('copy', Icons.copy, 'Sao chép lời'),
                    ('translate', Icons.translate, 'Dịch lời bằng AI'),
                    ('reset', Icons.delete_outline, 'Xóa lời đã lưu'),
                  ],
                  (
                    'awake',
                    Icons.light_mode_outlined,
                    _keepAwake ? 'Cho phép tắt màn hình' : 'Giữ màn hình sáng',
                  ),
                  ('preferences', Icons.tune, 'Giao diện và nguồn lời'),
                  ('aiSettings', Icons.auto_awesome, 'Cấu hình dịch AI'),
                ])
                  ListTile(
                    leading: Icon(item.$2),
                    title: Text(item.$3),
                    onTap: () => Navigator.pop(context, item.$1),
                  ),
              ],
            ),
          ),
    );
    if (mounted && action != null) await _action(action);
    if (mounted) _interact();
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
    return NotificationListener<ScrollNotification>(
      onNotification: (event) {
        if (event is ScrollStartNotification && event.dragDetails != null) {
          setState(() => _following = false);
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 130, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _lyrics.lines.length; i++)
              PixelLyricLine(
                key: _anchors.putIfAbsent(i, () => GlobalKey()),
                line: _lyrics.lines[i],
                index: i,
                provider: _lyrics,
                plain: _plain,
                immersive: _hidden,
                onTap:
                    _lyrics.lines[i].time == null
                        ? null
                        : () {
                          _player.seekTo(
                            _lyrics.seekPosition(_lyrics.lines[i]),
                          );
                          _lyrics.updatePosition(
                            _lyrics.seekPosition(_lyrics.lines[i]),
                          );
                          setState(() => _following = true);
                          _follow();
                        },
              ),
            const SizedBox(height: 16),
            Text(
              _lyrics.document?.source ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
            if (_lyrics.message != null)
              Text(_lyrics.message!, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _controls(BuildContext context) {
    final c = context.appColors;
    final duration =
        _data?.duration.inMilliseconds ?? _player.currentSong?.duration ?? 0;
    final position =
        (_seekPreview ?? (_data?.position.inMilliseconds ?? 0).toDouble())
            .clamp(0, duration > 0 ? duration : 0)
            .toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: _motion,
            child:
                !_showSync || !_lyrics.isSynced
                    ? const SizedBox.shrink()
                    : Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        children: [
                          for (final delta in [-500, -100])
                            TextButton(
                              onPressed:
                                  () => _lyrics.setOffset(
                                    _lyrics.offsetMs + delta,
                                  ),
                              child: Text('${delta / 1000}s'),
                            ),
                          TextButton(
                            onPressed: () => _lyrics.setOffset(0),
                            child: Text(
                              '${(_lyrics.offsetMs / 1000).toStringAsFixed(1)}s',
                            ),
                          ),
                          for (final delta in [100, 500])
                            TextButton(
                              onPressed:
                                  () => _lyrics.setOffset(
                                    _lyrics.offsetMs + delta,
                                  ),
                              child: Text('+${delta / 1000}s'),
                            ),
                        ],
                      ),
                    ),
          ),
          Row(
            children: [
              Semantics(
                button: true,
                label: _player.isPlaying ? 'Tạm dừng' : 'Phát',
                child: AnimatedContainer(
                  duration: _motion,
                  curve: Curves.easeOutBack,
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(
                      _player.isPlaying ? 18 : 50,
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _player.playPause();
                    },
                    icon: AnimatedSwitcher(
                      duration: _motion,
                      child: Icon(
                        _player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        key: ValueKey(_player.isPlaying),
                        size: 32,
                        color: c.background,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LyricsSeekBar(
                  value: position,
                  duration: duration.toDouble(),
                  playing: _player.isPlaying,
                  onChanged:
                      duration <= 0
                          ? null
                          : (value) {
                            setState(() => _seekPreview = value);
                            _lyrics.updatePosition(
                              Duration(milliseconds: value.round()),
                            );
                          },
                  onCommit: (value) {
                    _player.seekTo(Duration(milliseconds: value.round()));
                    setState(() => _seekPreview = null);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Đóng lời bài hát',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _mode(
                  'Đồng bộ',
                  !_plain && _lyrics.isSynced,
                  _lyrics.isSynced
                      ? () {
                        setState(() {
                          _plain = false;
                          _following = true;
                        });
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _follow(),
                        );
                      }
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _mode(
                  'Văn bản',
                  _plain || !_lyrics.isSynced,
                  () => setState(() => _plain = true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Tùy chọn lời bài hát',
                onPressed: _more,
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mode(String label, bool selected, VoidCallback? onTap) {
    final c = context.appColors;
    return AnimatedContainer(
      duration: _motion,
      height: (MediaQuery.textScalerOf(context).scale(14) * 2 + 16).clamp(
        50,
        120,
      ),
      decoration: BoxDecoration(
        color: selected ? c.primary : c.surfaceElevated,
        borderRadius: BorderRadius.circular(selected ? 50 : 16),
      ),
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color:
                onTap == null
                    ? c.textDisabled
                    : selected
                    ? c.background
                    : c.textPrimary,
          ),
        ),
      ),
    );
  }
}
