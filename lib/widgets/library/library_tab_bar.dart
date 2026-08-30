import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import '../../providers/music_provider.dart';
import 'package:muziczz/core/app_strings.dart';

class LibraryTabBar extends StatelessWidget {
  const LibraryTabBar({super.key, required this.tabCtrl, required this.music});
  final TabController tabCtrl;
  final MusicProvider music;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: tabCtrl,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        _CountTab(label: AppStrings.songs, count: music.allSongs.length),
        _CountTab(
          label: AppStrings.tabPlaylistsShort,
          count: music.playlists.length,
        ),
        _CountTab(
          label: AppStrings.album,
          count: music.sortedAlbumGroups.length,
        ),
        _CountTab(
          label: AppStrings.artist,
          count: music.sortedArtistGroups.length,
        ),
        _CountTab(
          label: AppStrings.folders,
          count: music.sortedFolderGroups.length,
        ),
      ],
    );
  }
}

// ── Count tab ─────────────────────────────────────────────────────────────────

class _CountTab extends StatelessWidget {
  const _CountTab({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: c.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
