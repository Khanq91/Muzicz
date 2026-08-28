import 'package:flutter/material.dart' hide RepeatMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../models/song_item.dart';
import '../../providers/music_provider.dart';
import '../../providers/player_provider.dart';
import '../add_to_playlist_sheet.dart';

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
                    onTap: () => _navigateToAlbum(context, music, song),
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
                  _showEditDialog(context, song);
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
                  _showSongInfo(context, song);
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

  void _navigateToAlbum(
    BuildContext context,
    MusicProvider music,
    SongItem song,
  ) {
    final albumSongs = music.albumMap[song.album] ?? [];
    if (albumSongs.isEmpty) return;
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.92,
            minChildSize: 0.4,
            expand: false,
            builder:
                (_, scrollCtrl) => Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 36,
                      height: 4,
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
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: QueryArtworkWidget(
                                id: song.albumId,
                                type: ArtworkType.ALBUM,
                                artworkFit: BoxFit.cover,
                                artworkBorder: BorderRadius.zero,
                                keepOldArtwork: true,
                                nullArtworkWidget: Container(
                                  color: c.surfaceElevated,
                                  child: Icon(
                                    Icons.album_rounded,
                                    color: c.textDisabled,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.album,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${albumSongs.length} bài hát',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: c.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: c.divider),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        itemCount: albumSongs.length,
                        itemBuilder: (_, i) {
                          final s = albumSongs[i];
                          final isCurrentSong = s.id == song.id;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 2,
                            ),
                            leading:
                                isCurrentSong
                                    ? Icon(
                                      Icons.equalizer_rounded,
                                      color: c.primary,
                                      size: 24,
                                    )
                                    : Text(
                                      '${i + 1}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        color: c.textTertiary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            title: Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color:
                                    isCurrentSong ? c.primary : c.textPrimary,
                                fontWeight:
                                    isCurrentSong
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                              ),
                            ),
                            subtitle: Text(
                              s.durationFormatted,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: c.textTertiary,
                              ),
                            ),
                            onTap: () {
                              final player = context.read<PlayerProvider>();
                              player.playSongs(albumSongs, specificSong: s);
                              music.onSongPlayed(s.id);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
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

  void _showSongInfo(BuildContext context, SongItem song) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thông tin bài hát',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _infoRow(context, 'Tên bài', song.title),
                _infoRow(context, 'Nghệ sĩ', song.artist),
                _infoRow(context, 'Album', song.album),
                _infoRow(context, 'Thời lượng', song.durationFormatted),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.outfit(color: c.textTertiary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                color: c.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, SongItem song) {
    final titleCtrl = TextEditingController(text: song.title);
    final artistCtrl = TextEditingController(text: song.artist);
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sửa thông tin',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _metaField(ctx, 'Tên bài hát', titleCtrl),
                const SizedBox(height: 12),
                _metaField(ctx, 'Nghệ sĩ', artistCtrl),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Hủy',
                          style: GoogleFonts.outfit(color: c.textTertiary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: c.primary,
                        ),
                        onPressed: () {
                          final t = titleCtrl.text.trim();
                          final a = artistCtrl.text.trim();
                          if (t.isNotEmpty) {
                            context.read<MusicProvider>().updateSongMeta(
                              song.id,
                              t.isEmpty ? song.title : t,
                              a.isEmpty ? song.artist : a,
                            );
                          }
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          'Lưu',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    ).whenComplete(() {
      titleCtrl.dispose();
      artistCtrl.dispose();
    });
  }

  Widget _metaField(
    BuildContext context,
    String label,
    TextEditingController ctrl,
  ) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, color: c.textTertiary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: GoogleFonts.outfit(color: c.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: c.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.primary, width: 1),
            ),
          ),
        ),
      ],
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
