import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:provider/provider.dart';
import '../../models/song_item.dart';
import '../../providers/music_provider.dart';
import '../add_to_playlist_sheet.dart';
import 'package:muziczz/core/app_strings.dart';

class SongInfo extends StatelessWidget {
  const SongInfo({super.key, required this.song});
  final SongItem song;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final isFav = music.isFavorite(song.id);
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
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
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.onPlayer,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${song.artist} · ${song.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: c.onPlayerMedium,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: AppStrings.addToPlaylist,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder:
                    (_) => ChangeNotifierProvider.value(
                      value: context.read<MusicProvider>(),
                      child: AddToPlaylistSheet(song: song),
                    ),
              );
            },
            icon: Icon(
              Icons.playlist_add_rounded,
              color: c.onPlayerLow,
              size: 26,
            ),
          ),
          MergeSemantics(
            child: Semantics(
              toggled: isFav,
              child: IconButton(
                tooltip: isFav ? AppStrings.unfavorite : AppStrings.favorites,
                onPressed: () {
                  music.toggleFavorite(song.id);
                  HapticFeedback.selectionClick();
                },
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder:
                      (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey(isFav),
                    color: isFav ? c.tertiary : c.onPlayerLow,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
