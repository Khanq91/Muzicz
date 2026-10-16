import 'package:flutter/material.dart';
import '../../models/song_item.dart';
import '../../core/app_strings.dart';
import '../../theme/app_colors_data.dart';

class SongInfo extends StatelessWidget {
  const SongInfo({super.key, required this.song, required this.onLyrics});
  final SongItem song;
  final VoidCallback onLyrics;
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: AppStrings.lyrics,
            style: IconButton.styleFrom(
              backgroundColor: c.background,
              minimumSize: const Size(48, 48),
            ),
            onPressed: onLyrics,
            icon: const Icon(Icons.lyrics_outlined),
          ),
        ],
      ),
    );
  }
}
