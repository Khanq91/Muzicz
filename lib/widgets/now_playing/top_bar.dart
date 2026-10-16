import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:provider/provider.dart';
import '../../models/song_item.dart';
import '../../providers/music_provider.dart';
import '../add_to_playlist_sheet.dart';
import 'sheets/album_songs_sheet.dart';
import 'sheets/edit_song_sheet.dart';
import 'sheets/song_info_sheet.dart';
import 'package:muziczz/core/app_strings.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.song,
    required this.onQueue,
    required this.onOutput,
    required this.onSpeed,
    required this.onTimer,
  });
  final SongItem song;
  final VoidCallback onQueue;
  final VoidCallback onOutput;
  final VoidCallback onSpeed;
  final VoidCallback onTimer;
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final surface = c.surfaceElevated;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: AppStrings.close,
            style: IconButton.styleFrom(backgroundColor: surface),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Now Playing',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17, color: c.textPrimary),
            ),
          ),
          IconButton.filledTonal(
            tooltip: AppStrings.audioOutput,
            style: IconButton.styleFrom(
              backgroundColor: surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(28),
                  right: Radius.circular(7),
                ),
              ),
            ),
            onPressed: onOutput,
            icon: const Icon(Icons.phonelink_ring_rounded),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            tooltip: AppStrings.queue,
            style: IconButton.styleFrom(
              backgroundColor: surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(7),
                  right: Radius.circular(28),
                ),
              ),
            ),
            onPressed: onQueue,
            icon: const Icon(Icons.queue_music_rounded),
          ),
          SongOverflowMenu(song: song, onSpeed: onSpeed, onTimer: onTimer),
        ],
      ),
    );
  }
}

class SongOverflowMenu extends StatelessWidget {
  const SongOverflowMenu({
    super.key,
    required this.song,
    this.onSpeed,
    this.onTimer,
  });
  final SongItem song;
  final VoidCallback? onSpeed;
  final VoidCallback? onTimer;
  @override
  Widget build(BuildContext context) {
    final music = context.read<MusicProvider>();
    final c = context.appColors;
    return PopupMenuButton<String>(
      tooltip: AppStrings.songOptions,
      icon: Icon(Icons.more_vert_rounded, size: 24, color: c.playerForeground),
      color: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (val) {
        switch (val) {
          case 'speed':
            onSpeed?.call();
            break;
          case 'timer':
            onTimer?.call();
            break;
          case 'album':
            showAlbumSongsSheet(context, music, song);
            break;
          case 'edit':
            showEditSongSheet(context, song);
            break;
          case 'hide':
            _showHideConfirm(context, song);
            break;
          case 'fav':
            context.read<MusicProvider>().toggleFavorite(song.id);
            break;
          case 'playlist':
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
            break;
          case 'info':
            showSongInfoSheet(context, song);
            break;
          case 'share':
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.shareText(song.title)),
                duration: const Duration(seconds: 2),
                backgroundColor: c.surfaceElevated,
              ),
            );
            break;
        }
      },
      itemBuilder: (_) {
        final isFav = context.read<MusicProvider>().isFavorite(song.id);
        return [
          if (onSpeed != null)
            _popItem(
              context,
              'speed',
              Icons.speed_rounded,
              AppStrings.playbackSpeed,
            ),
          if (onTimer != null)
            _popItem(
              context,
              'timer',
              Icons.bedtime_outlined,
              AppStrings.sleepTimer,
            ),
          _popItem(
            context,
            'album',
            Icons.album_outlined,
            AppStrings.albumSongsHint,
          ),
          _popItem(
            context,
            'fav',
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            isFav ? AppStrings.unfavorite : AppStrings.favorites,
            iconColor: isFav ? c.tertiary : null,
          ),
          _popItem(
            context,
            'playlist',
            Icons.playlist_add_rounded,
            AppStrings.addToPlaylist,
          ),
          _popItem(context, 'edit', Icons.edit_rounded, AppStrings.editInfo),
          _popItem(
            context,
            'hide',
            Icons.visibility_off_rounded,
            AppStrings.hideFromLibrary,
          ),
          _popItem(context, 'share', Icons.share_rounded, AppStrings.share),
          _popItem(
            context,
            'info',
            Icons.info_outline_rounded,
            AppStrings.songInfo,
          ),
        ];
      },
    );
  }

  PopupMenuItem<String> _popItem(
    BuildContext context,
    String val,
    IconData icon,
    String label, {
    Color? iconColor,
  }) {
    final c = context.appColors;
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? c.textSecondary, size: 20),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.outfit(color: c.textPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showHideConfirm(BuildContext context, SongItem song) {
    final c = context.appColors;
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              AppStrings.hideSongTitle,
              style: GoogleFonts.outfit(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              AppStrings.hideSongBody(song.title),
              style: GoogleFonts.outfit(color: c.textSecondary, height: 1.6),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppStrings.cancel,
                  style: GoogleFonts.outfit(color: c.textTertiary),
                ),
              ),
              TextButton(
                onPressed: () {
                  context.read<MusicProvider>().hideSongFromLibrary(song);
                  Navigator.pop(context);
                },
                child: Text(
                  AppStrings.hide,
                  style: GoogleFonts.outfit(
                    color: c.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
