import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../theme/app_colors.dart';

class MusicListTile extends StatelessWidget {
  const MusicListTile({
    super.key,
    required this.song,
    required this.onTap,
    this.showAlbumArt = true,
    this.trailing,
    this.isActive = false,
    this.index,
  });

  final SongItem song;
  final VoidCallback onTap;
  final bool showAlbumArt;
  final Widget? trailing;
  final bool isActive;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();
    final isFav = musicProvider.isFavorite(song.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showContextMenu(context, isFav, musicProvider),
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primary.withOpacity(0.1),
        highlightColor: AppColors.primary.withOpacity(0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isActive
                ? AppColors.primary.withOpacity(0.08)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              if (showAlbumArt) ...[
                _AlbumArtThumbnail(
                  albumId: song.albumId,
                  isActive: isActive,
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${song.artist} · ${song.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null)
                trailing!
              else
                Text(
                  song.durationFormatted,
                  style: const TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(
    BuildContext context,
    bool isFav,
    MusicProvider musicProvider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SongContextMenu(
        song: song,
        isFavorite: isFav,
        onFavoriteToggle: () => musicProvider.toggleFavorite(song.id),
      ),
    );
  }
}

class _AlbumArtThumbnail extends StatelessWidget {
  const _AlbumArtThumbnail({required this.albumId, this.isActive = false});
  final int albumId;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.surfaceElevated,
        border: isActive
            ? Border.all(color: AppColors.primary, width: 1.5)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: QueryArtworkWidget(
          id: albumId,
          type: ArtworkType.ALBUM,
          artworkFit: BoxFit.cover,
          artworkBorder: BorderRadius.zero,
          nullArtworkWidget: const _DefaultArtwork(),
          keepOldArtwork: true,
        ),
      ),
    );
  }
}

class _DefaultArtwork extends StatelessWidget {
  const _DefaultArtwork();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      child: const Icon(
        Icons.music_note_rounded,
        color: AppColors.textDisabled,
        size: 22,
      ),
    );
  }
}

class _SongContextMenu extends StatelessWidget {
  const _SongContextMenu({
    required this.song,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final SongItem song;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Song info header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _AlbumArtThumbnail(albumId: song.albumId),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        song.artist,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.divider),
          _ContextMenuItem(
            icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            iconColor: isFavorite ? AppColors.tertiary : null,
            label: isFavorite ? 'Bỏ yêu thích' : 'Thêm vào yêu thích',
            onTap: () {
              onFavoriteToggle();
              Navigator.pop(context);
            },
          ),
          _ContextMenuItem(
            icon: Icons.playlist_add_rounded,
            label: 'Thêm vào playlist',
            onTap: () => Navigator.pop(context),
          ),
          _ContextMenuItem(
            icon: Icons.queue_music_rounded,
            label: 'Thêm vào hàng chờ',
            onTap: () => Navigator.pop(context),
          ),
          _ContextMenuItem(
            icon: Icons.info_outline_rounded,
            label: 'Chi tiết bài hát',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _ContextMenuItem extends StatelessWidget {
  const _ContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }
}
