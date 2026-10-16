import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../../providers/music_provider.dart';
import '../../providers/player_provider.dart';
import '../../theme/app_colors_data.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/library/library_empty_state.dart';
import '../../widgets/music_list_tile.dart';

class SongsTab extends StatelessWidget {
  const SongsTab({
    super.key,
    required this.onScanTap,
    required this.onClearSearch,
  });

  final VoidCallback onScanTap;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final songs = music.librarySongsSortedBy(LibrarySongSort.title);
    final hasMiniPlayer = context.select<PlayerProvider, bool>(
      (player) => player.currentSong != null,
    );

    if (music.status == LibraryStatus.scanning && music.allSongs.isEmpty) {
      final c = context.appColors;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.libraryLoadingEllipsis,
              style: GoogleFonts.outfit(color: c.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (songs.isEmpty) {
      final isSearching = music.librarySearchQuery.trim().isNotEmpty;
      return LibraryEmptyState(
        icon: isSearching ? Icons.search_off_rounded : Icons.music_note_rounded,
        message:
            isSearching ? AppStrings.noResultsDot : AppStrings.emptyLibrary,
        showSearchTip: isSearching,
        searchQuery: music.librarySearchQuery,
        onScanTap: isSearching ? null : onScanTap,
        onClearSearch: isSearching ? onClearSearch : null,
      );
    }

    final player = context.read<PlayerProvider>();
    return ListView.builder(
      key: const PageStorageKey<String>('library_songs'),
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: 8,
        bottom: AppBottomNavigation.scrollBottomPadding(
          context,
          hasMiniPlayer: hasMiniPlayer,
        ),
      ),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return Selector<PlayerProvider, int?>(
          key: ValueKey('library_song_${song.id}'),
          selector: (_, state) => state.currentSong?.id,
          builder:
              (_, activeId, __) => MusicListTile(
                song: song,
                isActive: activeId == song.id,
                onTap: () => player.playSongs(songs, specificSong: song),
              ),
        );
      },
    );
  }
}
