import 'dart:math' as math;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:on_audio_query/on_audio_query.dart';
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
import '../widgets/track_swipe.dart';

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

  void _queue() => _sheet(
    (sheetContext) =>
        QueueSheet(onClose: () => Navigator.pop(sheetContext), useBlur: false),
    height: MediaQuery.sizeOf(context).height * 0.72,
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
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(song: song),
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
                    560.0 + extraText,
                  );
                  final artSize = math.min(
                    constraints.maxWidth * 0.84,
                    height - 324 - extraText,
                  );
                  final content = SizedBox(
                    height: height,
                    child: Column(
                      children: [
                        const Spacer(),
                        SizedBox(
                          height: artSize,
                          child: TrackSwipe(
                            onNext: _player.skipToNext,
                            onPrevious: _player.skipToPrevious,
                            child: Center(
                              child: _PlayerArtwork(song: song, size: artSize),
                            ),
                          ),
                        ),
                        const Spacer(),
                        SongInfo(song: song),
                        const SizedBox(height: 16),
                        ProgressSection(player: _player),
                        const SizedBox(height: 12),
                        ControlsSection(player: _player),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: _lyrics,
                                tooltip: AppStrings.lyrics,
                                icon: const Icon(Icons.lyrics_rounded),
                              ),
                              IconButton(
                                tooltip: AppStrings.playbackSpeed,
                                icon: const Icon(Icons.speed_rounded),
                                onPressed:
                                    () => _sheet((_) => const SpeedSheet()),
                              ),
                              IconButton(
                                tooltip: AppStrings.sleepTimer,
                                icon: const Icon(Icons.bedtime_outlined),
                                onPressed:
                                    () =>
                                        _sheet((_) => const SleepTimerSheet()),
                              ),
                              IconButton(
                                tooltip: AppStrings.queue,
                                icon: const Icon(Icons.queue_music_rounded),
                                onPressed: _queue,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
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

class _PlayerArtwork extends StatelessWidget {
  const _PlayerArtwork({required this.song, required this.size});
  final SongItem song;
  final double size;

  @override
  Widget build(BuildContext context) {
    final playing = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    final c = context.appColors;
    return AnimatedScale(
      scale: playing ? 1 : 0.95,
      duration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: SizedBox.square(
            dimension: size,
            child: QueryArtworkWidget(
              key: ValueKey(song.albumId),
              id: song.albumId,
              type: ArtworkType.ALBUM,
              artworkWidth: size,
              artworkHeight: size,
              artworkFit: BoxFit.cover,
              artworkBorder: BorderRadius.zero,
              keepOldArtwork: true,
              nullArtworkWidget: DecoratedBox(
                decoration: BoxDecoration(gradient: c.primaryGradient),
                child: Icon(
                  Icons.music_note_rounded,
                  size: 96,
                  color: c.onPlayer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
