import 'dart:math' as math;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_strings.dart';
import '../models/song_item.dart';
import '../providers/lyrics_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors_data.dart';
import '../widgets/now_playing/controls.dart';
import '../widgets/now_playing/lyrics_view.dart';
import '../widgets/now_playing/song_info.dart';
import '../widgets/now_playing/top_bar.dart';
import '../widgets/now_playing/sheets/queue_sheet.dart';
import '../widgets/now_playing/sheets/sleep_timer_sheet.dart';
import '../widgets/now_playing/sheets/speed_sheet.dart';
import '../widgets/now_playing/album_carousel.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});
  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final _lyricsScroll = ScrollController();
  late final PlayerProvider _player;
  int? _lyricsSongId;

  @override
  void initState() {
    super.initState();
    _player = context.read<PlayerProvider>()..addListener(_loadLyrics);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLyrics());
  }

  void _loadLyrics() {
    if (!mounted) return;
    final song = _player.currentSong;
    if (song != null && song.id != _lyricsSongId) {
      _lyricsSongId = song.id;
      context.read<LyricsProvider>().loadLyrics(song);
    }
  }

  @override
  void dispose() {
    _player.removeListener(_loadLyrics);
    _lyricsScroll.dispose();
    super.dispose();
  }

  void _scrollToLine(int index) {
    if (!_lyricsScroll.hasClients || index < 0) return;
    final position = _lyricsScroll.position;
    _lyricsScroll.animateTo(
      (index * 52.0 - position.viewportDimension / 2 + 26).clamp(
        0.0,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _sheet(Widget Function(BuildContext) builder, {double? height}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (sheetContext) =>
              SizedBox(height: height, child: builder(sheetContext)),
    );
  }

  void _queue() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: AnimationStyle(
      duration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 380),
      reverseDuration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
    ),
    builder:
        (sheetContext) => DraggableScrollableSheet(
          initialChildSize: 1,
          minChildSize: .45,
          maxChildSize: 1,
          expand: false,
          snap: true,
          builder:
              (_, scrollController) => QueueSheet(
                onClose: () => Navigator.pop(sheetContext),
                useBlur: false,
                scrollController: scrollController,
              ),
        ),
  );

  void _lyrics() => _sheet(
    (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.lyrics,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            LyricsView(
              player: _player,
              scrollCtrl: _lyricsScroll,
              onScrollToLine: _scrollToLine,
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _output() async {
    try {
      await const MethodChannel(
        'muzicz/audio_output',
      ).invokeMethod<void>('showOutputSwitcher');
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.outputUnavailable)),
        );
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.outputAndroidOnly)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = context.select<PlayerProvider, SongItem?>(
      (p) => p.currentSong,
    );
    final c = context.appColors;
    if (song == null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(leading: const CloseButton()),
      );
    }
    return Scaffold(
      backgroundColor: Color.lerp(
        c.background,
        c.primary,
        c.isDark ? .10 : .14,
      ),
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              song: song,
              onQueue: _queue,
              onOutput: _output,
              onSpeed: () => _sheet((_) => const SpeedSheet()),
              onTimer: () => _sheet((_) => const SleepTimerSheet()),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final extraText =
                      (MediaQuery.textScalerOf(context).scale(48) - 48).clamp(
                        0.0,
                        180.0,
                      );
                  final height = math.max(
                    constraints.maxHeight,
                    620.0 + extraText,
                  );
                  final artSize = math.min(
                    constraints.maxWidth - 44,
                    height - 390 - extraText,
                  );
                  final content = SizedBox(
                    height: height,
                    child: Column(
                      children: [
                        const Spacer(),
                        SizedBox(
                          width: artSize + 44,
                          height: artSize,
                          child: AlbumCarousel(player: _player),
                        ),
                        const Spacer(),
                        SongInfo(song: song, onLyrics: _lyrics),
                        const SizedBox(height: 16),
                        ProgressSection(player: _player),
                        const SizedBox(height: 24),
                        ControlsSection(player: _player),
                        const SizedBox(height: 20),
                        PlayerToggleRow(player: _player),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                  if (constraints.maxHeight < height) {
                    return SingleChildScrollView(child: content);
                  }
                  return content;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
