import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:provider/provider.dart';
import '../../models/song_item.dart';
import '../../providers/music_provider.dart';
import '../../providers/player_provider.dart';
import '../music_list_tile.dart';
import 'package:muziczz/core/app_strings.dart';
import 'library_empty_state.dart';
import 'player_route.dart';
import 'sort_type.dart';

class SongsTab extends StatelessWidget {
  const SongsTab({
    super.key,
    required this.sortType,
    required this.onScanTap,
    this.isSelecting = false,
    this.selectedIds = const {},
    this.onEnterSelect,
    this.onToggleSelect,
  });
  final SortType sortType;
  final VoidCallback onScanTap;
  final bool isSelecting;
  final Set<int> selectedIds;
  final void Function(SongItem)? onEnterSelect;
  final void Function(SongItem)? onToggleSelect;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<PlayerProvider>();
    final c = context.appColors;
    final songs = music.librarySongsSortedBy(switch (sortType) {
      SortType.az => LibrarySongSort.title,
      SortType.recentlyAdded => LibrarySongSort.recentlyAdded,
      SortType.duration => LibrarySongSort.duration,
    });

    if (songs.isEmpty) {
      return LibraryEmptyState(
        icon: Icons.music_note_rounded,
        message:
            music.librarySearchQuery.isEmpty
                ? AppStrings.emptyLibrary
                : AppStrings.noResultsDot,
        showSearchTip: music.librarySearchQuery.isNotEmpty,
        searchQuery: music.librarySearchQuery,
        onScanTap: music.librarySearchQuery.isEmpty ? onScanTap : null,
      );
    }

    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.card,
      onRefresh: () => context.read<MusicProvider>().scanMusic(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        // Extra padding khi selecting để action bar không che list
        padding: EdgeInsets.only(bottom: isSelecting ? 8 : 12),
        itemCount: songs.length,
        itemBuilder: (_, i) {
          final song = songs[i];
          return MusicListTile(
            song: song,
            isActive: !isSelecting && player.currentSong?.id == song.id,
            isSelecting: isSelecting,
            isSelected: selectedIds.contains(song.id),
            onTap:
                isSelecting
                    ? () => onToggleSelect?.call(song)
                    : () {
                      context.read<PlayerProvider>().playSongs(
                        songs,
                        specificSong: song,
                      );
                      Navigator.of(context).push(playerRoute());
                    },
            onLongPress:
                isSelecting
                    ? null
                    : () {
                      HapticFeedback.mediumImpact();
                      onEnterSelect?.call(song);
                    },
          );
        },
      ),
    );
  }
}
