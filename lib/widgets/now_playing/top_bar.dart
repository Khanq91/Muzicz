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

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.song});
  final SongItem song;

  @override
  Widget build(BuildContext context) {
    final music = context.read<MusicProvider>();
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Đóng',
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 32,
              color: c.onPlayer,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'ĐANG PHÁT',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                    color: c.onPlayerLow,
                    letterSpacing: 2.5,
                  ),
                ),
                Semantics(
                  button: true,
                  child: GestureDetector(
                    onTap: () => showAlbumSongsSheet(context, music, song),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.album.isNotEmpty ? song.album : 'Từ thư viện',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: c.onPlayerHigh,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white38,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: c.onPlayerSubtle,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 24, color: c.onPlayer),
            color: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (val) {
              switch (val) {
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
                      content: Text('Chia sẻ: ${song.title}'),
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
                _popItem(
                  context,
                  'fav',
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  isFav ? 'Bỏ yêu thích' : 'Yêu thích',
                  iconColor: isFav ? c.tertiary : null,
                ),
                _popItem(
                  context,
                  'playlist',
                  Icons.playlist_add_rounded,
                  'Thêm vào danh sách phát',
                ),
                _popItem(context, 'edit', Icons.edit_rounded, 'Sửa thông tin'),
                _popItem(
                  context,
                  'hide',
                  Icons.visibility_off_rounded,
                  'Ẩn khỏi thư viện',
                ),
                _popItem(context, 'share', Icons.share_rounded, 'Chia sẻ'),
                _popItem(
                  context,
                  'info',
                  Icons.info_outline_rounded,
                  'Thông tin bài hát',
                ),
              ];
            },
          ),
        ],
      ),
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
          Text(
            label,
            style: GoogleFonts.outfit(color: c.textPrimary, fontSize: 14),
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
              'Ẩn bài hát?',
              style: GoogleFonts.outfit(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              '"${song.title}" sẽ bị ẩn khỏi thư viện. File gốc không bị xóa. Có thể quét lại để khôi phục.',
              style: GoogleFonts.outfit(color: c.textSecondary, height: 1.6),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Hủy',
                  style: GoogleFonts.outfit(color: c.textTertiary),
                ),
              ),
              TextButton(
                onPressed: () {
                  context.read<MusicProvider>().hideSongFromLibrary(song);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text(
                  'Ẩn',
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
