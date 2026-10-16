import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../core/app_strings.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors_data.dart';
import 'now_playing/top_bar.dart';

class HomeActionButton extends StatefulWidget {
  const HomeActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.size,
    required this.color,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback? onTap;
  @override
  State<HomeActionButton> createState() => _HomeActionButtonState();
}

class _HomeActionButtonState extends State<HomeActionButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .9 : 1,
    duration:
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 380),
    curve: Curves.easeOutBack,
    child: SizedBox.square(
      dimension: widget.size,
      child: Material(
        color: widget.color,
        shape: const CircleBorder(),
        child: Tooltip(
          message: widget.label,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
            child: Semantics(
              button: true,
              label: widget.label,
              child: Icon(
                widget.icon,
                size: widget.size * .38,
                color: context.appColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class HomeSongCollage extends StatelessWidget {
  const HomeSongCollage({
    super.key,
    required this.songs,
    required this.onSongTap,
  });
  final List<SongItem> songs;
  final ValueChanged<SongItem> onSongTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 38),
    child: AspectRatio(
      aspectRatio: 1.02,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          // PixelPlayer's freeform pattern: a diagonal capsule, two satellites,
          // and two lower cutouts. Stable positions avoid reshuffling on rebuild.
          const positions = [
            (.29, .02, .43, .58, math.pi / 4),
            (.01, .01, .20, .20, 0.0),
            (.78, .36, .20, .20, 0.0),
            (.10, .67, .25, .30, -.35),
            (.60, .63, .37, .36, .10),
          ];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < math.min(5, songs.length); i++)
                Positioned(
                  left: positions[i].$1 * w,
                  top: positions[i].$2 * h,
                  width: positions[i].$3 * w,
                  height: positions[i].$4 * h,
                  child: Transform.rotate(
                    angle: positions[i].$5,
                    child: _CollageCover(
                      song: songs[i],
                      cutout: i > 2,
                      onTap: () => onSongTap(songs[i]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _CollageCover extends StatelessWidget {
  const _CollageCover({
    required this.song,
    required this.cutout,
    required this.onTap,
  });
  final SongItem song;
  final bool cutout;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${song.title}, ${song.artist}',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(cutout ? 30 : 120),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: RepaintBoundary(
            child: QueryArtworkWidget(
              id: song.albumId,
              type: ArtworkType.ALBUM,
              artworkBorder: BorderRadius.zero,
              artworkFit: BoxFit.cover,
              keepOldArtwork: true,
              nullArtworkWidget: ColoredBox(
                color:
                    cutout
                        ? Colors.transparent
                        : context.appColors.surfaceElevated,
                child: LayoutBuilder(
                  builder:
                      (_, size) => Icon(
                        Icons.music_note_rounded,
                        size: size.biggest.shortestSide * .9,
                        color: context.appColors.textDisabled,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class HomeSongSection extends StatelessWidget {
  const HomeSongSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.songs,
    this.onViewAll,
  });
  final String title;
  final String subtitle;
  final List<SongItem> songs;
  final VoidCallback? onViewAll;
  void _open(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: ListView.builder(
              itemCount: songs.length,
              itemBuilder: (_, i) => _SongRow(song: songs[i], songs: songs),
            ),
          ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Material(
          color: c.surfaceElevated,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(c.primary, c.surface, .35)!,
                      Color.lerp(c.tertiary, c.surface, .45)!,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 88,
                      height: 48,
                      child: Stack(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Positioned(
                              left: i * 21,
                              top: i == 1 ? 0 : 5,
                              child: Container(
                                width: 46,
                                height: 43,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white70,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    i == 1 ? 40 : 14,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Column(
                  children: [
                    for (final song in songs.take(4))
                      _SongRow(song: song, songs: songs),
                  ],
                ),
              ),
              InkWell(
                onTap: onViewAll ?? () => _open(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.viewAll,
                          style: TextStyle(
                            fontSize: 17,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: c.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({required this.song, required this.songs});
  final SongItem song;
  final List<SongItem> songs;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Material(
      color: context.appColors.background.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap:
            () => context.read<PlayerProvider>().playSongs(
              songs,
              specificSong: song,
            ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: context.appColors.surfaceElevated,
                shape: const CircleBorder(),
                child: SongOverflowMenu(song: song),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class HomeListeningSections extends StatelessWidget {
  const HomeListeningSections({super.key});
  @override
  Widget build(BuildContext context) {
    final recent = context.select<MusicProvider, List<SongItem>>(
      (p) => p.recentlyPlayed,
    );
    final added = context.select<MusicProvider, List<SongItem>>(
      (p) => p.recentlyAdded,
    );
    final total = context.select<MusicProvider, int>((p) => p.totalPlayCount);
    return Column(
      children: [
        if (recent.isNotEmpty)
          HomeSongSection(
            title: AppStrings.recentlyPlayed,
            subtitle: AppStrings.fromListeningHistory,
            songs: recent,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Material(
            color: context.appColors.surfaceElevated,
            borderRadius: BorderRadius.circular(30),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap:
                  () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder:
                        (_) => SafeArea(
                          child: SingleChildScrollView(
                            child: HomeSongSection(
                              title: AppStrings.mostPlayedTitle,
                              subtitle: AppStrings.allTimePlays,
                              songs: context.read<MusicProvider>().mostPlayed,
                            ),
                          ),
                        ),
                  ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            AppStrings.listeningStats,
                            style: TextStyle(fontSize: 20),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            AppStrings.totalPlaysLabel(total),
                            style: TextStyle(
                              color: context.appColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (added.isNotEmpty)
          HomeSongSection(
            title: AppStrings.recentlyAdded,
            subtitle: AppStrings.inYourLibrary,
            songs: added,
          ),
      ],
    );
  }
}
