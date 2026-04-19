import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import 'add_to_playlist_sheet.dart';

class MusicListTile extends StatelessWidget {
  const MusicListTile({
    super.key,
    required this.song,
    required this.onTap,
    this.showAlbumArt = true,
    this.trailing,
    this.isActive = false,
    this.index,
    // ── Selection support ──────────────────────────────────────────────────
    this.isSelecting = false,
    this.isSelected = false,
    this.onLongPress, // overrides default context menu
  });

  final SongItem song;
  final VoidCallback onTap;
  final bool showAlbumArt;
  final Widget? trailing;
  final bool isActive;
  final int? index;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();
    final isFav = musicProvider.isFavorite(song.id);
    final c = context.appColors;

    final bgColor = isSelected
        ? c.primary.withOpacity(0.14)
        : isActive
        ? c.primary.withOpacity(0.08)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: isSelecting
            ? null
            : (onLongPress ??
                () {
              HapticFeedback.mediumImpact();
              _showContextMenu(context, isFav, musicProvider);
            }),
        borderRadius: BorderRadius.circular(12),
        splashColor: c.primary.withOpacity(0.1),
        highlightColor: c.primary.withOpacity(0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: bgColor,
          ),
          child: Row(
            children: [
              if (showAlbumArt) ...[
                _AlbumArtWithCheckbox(
                  albumId: song.albumId,
                  isActive: isActive && !isSelecting,
                  isSelecting: isSelecting,
                  isSelected: isSelected,
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
                        color: isSelected || isActive ? c.primary : c.textPrimary,
                        fontSize: 15,
                        fontWeight: isActive || isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${song.artist} · ${song.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isSelecting) ...[
                if (trailing != null)
                  trailing!
                else
                  Text(
                    song.durationFormatted,
                    style: TextStyle(
                      color: c.textDisabled,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(
      BuildContext context, bool isFav, MusicProvider musicProvider) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SongContextMenu(
        song: song,
        isFavorite: isFav,
        onFavoriteToggle: () => musicProvider.toggleFavorite(song.id),
        parentContext: context,
      ),
    );
  }
}

// ── Album art với selection overlay ──────────────────────────────────────────

class _AlbumArtWithCheckbox extends StatelessWidget {
  const _AlbumArtWithCheckbox({
    required this.albumId,
    required this.isActive,
    required this.isSelecting,
    required this.isSelected,
  });
  final int albumId;
  final bool isActive;
  final bool isSelecting;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          _AlbumArtThumbnail(albumId: albumId, isActive: isActive),
          if (isSelecting)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isSelected
                    ? c.primary.withOpacity(0.65)
                    : Colors.black.withOpacity(0.35),
              ),
              child: Center(
                child: Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Album art thumbnail ───────────────────────────────────────────────────────

class _AlbumArtThumbnail extends StatelessWidget {
  const _AlbumArtThumbnail({required this.albumId, this.isActive = false});
  final int albumId;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: c.surfaceElevated,
        border:
        isActive ? Border.all(color: c.primary, width: 1.5) : null,
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
    final c = context.appColors;
    return Container(
      color: c.surfaceElevated,
      child: Icon(Icons.music_note_rounded,
          color: c.textDisabled, size: 22),
    );
  }
}

// ── Context menu ──────────────────────────────────────────────────────────────

class _SongContextMenu extends StatelessWidget {
  const _SongContextMenu({
    required this.song,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.parentContext,
  });

  final SongItem song;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: c.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
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
                      Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      Text(song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.textTertiary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: c.divider),

          _ContextMenuItem(
            icon: isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            iconColor: isFavorite ? c.tertiary : null,
            label: isFavorite ? 'Bỏ yêu thích' : 'Thêm vào yêu thích',
            onTap: () {
              onFavoriteToggle();
              Navigator.pop(context);
            },
          ),

          _ContextMenuItem(
            icon: Icons.playlist_add_rounded,
            label: 'Thêm vào danh sách phát',
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: parentContext,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => ChangeNotifierProvider.value(
                  value: parentContext.read<MusicProvider>(),
                  child: AddToPlaylistSheet(song: song),
                ),
              );
            },
          ),

          _ContextMenuItem(
            icon: Icons.queue_music_rounded,
            label: 'Phát tiếp theo',
            onTap: () {
              final player = parentContext.read<PlayerProvider>();
              if (player.currentSong == null) {
                player.playSongs([song]);
              } else {
                player.addToQueue(song);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Đã thêm "${song.title}" vào hàng chờ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: c.surfaceElevated,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
              Navigator.pop(context);
            },
          ),

          _ContextMenuItem(
            icon: Icons.info_outline_rounded,
            label: 'Chi tiết bài hát',
            onTap: () {
              Navigator.pop(context);
              _showSongInfo(parentContext);
            },
          ),
        ],
      ),
    );
  }

  void _showSongInfo(BuildContext context) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thông tin bài hát',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _infoRow(context, 'Tên bài', song.title),
            _infoRow(context, 'Nghệ sĩ', song.artist),
            _infoRow(context, 'Album', song.album),
            _infoRow(context, 'Thời lượng', song.durationFormatted),
            _infoRow(context, 'Đường dẫn', song.data),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    color: c.textTertiary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
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
    final c = context.appColors;
    return ListTile(
      leading: Icon(icon,
          color: iconColor ?? c.textSecondary, size: 22),
      title: Text(label,
          style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w400)),
      onTap: onTap,
    );
  }
}