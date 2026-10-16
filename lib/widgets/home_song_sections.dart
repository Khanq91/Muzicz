import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../core/app_strings.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors_data.dart';

/// A bounded, stable collage: no random ordering or image work while scrolling.
class HomeSongCollage extends StatelessWidget {
  const HomeSongCollage({
    super.key,
    required this.songs,
    required this.onSongTap,
  });
  final List<SongItem> songs;
  final ValueChanged<SongItem> onSongTap;

  @override
  Widget build(BuildContext context) {
    final preview = songs.take(5).toList(growable: false);
    if (preview.isEmpty) return const SizedBox.shrink();
    Widget tile(int index, double radius) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: _SongCover(
          song: preview[index],
          radius: radius,
          onTap: () => onSongTap(preview[index]),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).width * 0.95).clamp(240.0, 420.0),
        child:
            preview.length < 3
                ? Row(
                  children: [
                    for (var i = 0; i < preview.length; i++) tile(i, 36),
                  ],
                )
                : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          tile(0, 36),
                          if (preview.length > 3)
                            Flexible(
                              child: Row(
                                children: [
                                  tile(3, 50),
                                  if (preview.length > 4) tile(4, 24),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Column(children: [tile(1, 70), tile(2, 28)]),
                    ),
                  ],
                ),
      ),
    );
  }
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
    return Column(
      children: [
        if (recent.isNotEmpty)
          _SongRail(title: AppStrings.recentlyPlayed, songs: recent),
        if (added.isNotEmpty)
          _SongRail(title: AppStrings.recentlyAdded, songs: added),
      ],
    );
  }
}

class _SongRail extends StatelessWidget {
  const _SongRail({required this.title, required this.songs});
  final String title;
  final List<SongItem> songs;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.appColors.textPrimary,
          ),
        ),
      ),
      SizedBox(
        height: 156 + MediaQuery.textScalerOf(context).scale(40),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: songs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final song = songs[index];
            return SizedBox(
              width: 144,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: 144,
                    child: _SongCover(
                      song: song,
                      onTap:
                          () => context.read<PlayerProvider>().playSongs(
                            songs,
                            specificSong: song,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _SongCover extends StatelessWidget {
  const _SongCover({required this.song, required this.onTap, this.radius = 24});
  final SongItem song;
  final VoidCallback onTap;
  final double radius;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${song.title}, ${song.artist}',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Material(
        color: context.appColors.surfaceElevated,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: QueryArtworkWidget(
                  id: song.albumId,
                  type: ArtworkType.ALBUM,
                  artworkFit: BoxFit.cover,
                  artworkBorder: BorderRadius.zero,
                  keepOldArtwork: true,
                  nullArtworkWidget: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: context.appColors.primaryGradient,
                    ),
                    child: const Center(
                      child: Icon(Icons.music_note_rounded, size: 48),
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x80000000)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Text(
                  song.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
