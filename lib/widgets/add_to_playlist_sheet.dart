import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_item.dart';
import '../models/playlist_item.dart';
import '../providers/music_provider.dart';
import '../theme/app_colors.dart';

/// Sheet thêm bài hát vào playlist — phong cách YouTube.
/// Dùng được từ NowPlayingScreen, MusicListTile context menu, v.v.
///
/// Cách dùng:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   backgroundColor: Colors.transparent,
///   isScrollControlled: true,
///   builder: (_) => AddToPlaylistSheet(song: song),
/// );
/// ```
class AddToPlaylistSheet extends StatefulWidget {
  const AddToPlaylistSheet({super.key, required this.song});
  final SongItem song;

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PlaylistItem> _filtered(List<PlaylistItem> all) {
    if (_query.isEmpty) return all;
    return all
        .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final playlists = music.playlists;
    final filtered = _filtered(playlists);

    return Container(
      // Chiều cao 65% màn hình, có thể kéo lên
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lưu vào danh sách',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textTertiary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Nút tạo playlist mới ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _CreateNewButton(
              onTap: () => _showCreateDialog(context, music),
            ),
          ),

          // ── Thanh tìm kiếm (chỉ hiện khi có >= 3 playlists) ─────
          if (playlists.length >= 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (q) => setState(() => _query = q),
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Tìm danh sách…',
                  hintStyle: GoogleFonts.outfit(
                    color: AppColors.textDisabled,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textTertiary,
                      size: 18,
                    ),
                  )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    const BorderSide(color: AppColors.primary, width: 1),
                  ),
                ),
              ),
            ),

          // ── Danh sách playlist ───────────────────────────────────
          Flexible(
            child: playlists.isEmpty
                ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.playlist_play_rounded,
                    color: AppColors.textDisabled,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chưa có danh sách nào.\nNhấn "+ Tạo mới" để bắt đầu.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
                : filtered.isEmpty
                ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Không tìm thấy danh sách nào.',
                style: GoogleFonts.outfit(
                  color: AppColors.textTertiary,
                ),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final pl = filtered[i];
                final inPlaylist =
                pl.songs.any((s) => s.id == widget.song.id);
                return _PlaylistCheckTile(
                  playlist: pl,
                  checked: inPlaylist,
                  song: widget.song,
                  onChanged: (add) {
                    if (add) {
                      music.addToPlaylist(pl.id, widget.song);
                      _showFeedback(
                          context, 'Đã thêm vào "${pl.name}"');
                    } else {
                      music.removeFromPlaylist(
                          pl.id, widget.song.id);
                      _showFeedback(
                          context, 'Đã xóa khỏi "${pl.name}"');
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedback(BuildContext context, String message) {
    // Không close sheet — giống YouTube, user có thể thêm vào nhiều playlist
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, MusicProvider music) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Tạo danh sách mới',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.outfit(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Tên danh sách…',
            hintStyle: GoogleFonts.outfit(color: AppColors.textDisabled),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1),
            ),
          ),
          onSubmitted: (_) => _doCreate(dialogCtx, ctrl, music),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Hủy',
              style: GoogleFonts.outfit(color: AppColors.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () => _doCreate(dialogCtx, ctrl, music),
            child: Text(
              'Tạo & Thêm',
              style: GoogleFonts.outfit(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _doCreate(
      BuildContext dialogCtx,
      TextEditingController ctrl,
      MusicProvider music,
      ) {
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    final pl = music.createPlaylist(name);
    music.addToPlaylist(pl.id, widget.song);
    Navigator.pop(dialogCtx);
    _showFeedback(dialogCtx, 'Đã tạo "$name" và thêm bài hát');
  }
}

// ── Nút tạo mới ──────────────────────────────────────────────────────────────

class _CreateNewButton extends StatelessWidget {
  const _CreateNewButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.45),
              width: 1,
            ),
            color: AppColors.primary.withOpacity(0.06),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.18),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Tạo danh sách mới',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tile playlist với checkbox ────────────────────────────────────────────────

class _PlaylistCheckTile extends StatelessWidget {
  const _PlaylistCheckTile({
    required this.playlist,
    required this.checked,
    required this.song,
    required this.onChanged,
  });
  final PlaylistItem playlist;
  final bool checked;
  final SongItem song;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      onTap: () => onChanged(!checked),
      leading: _PlaylistMiniCover(playlist: playlist),
      title: Text(
        playlist.name,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        '${playlist.songCount} bài hát',
        style: GoogleFonts.outfit(
          fontSize: 12,
          color: AppColors.textTertiary,
        ),
      ),
      trailing: _AnimatedCheckbox(checked: checked),
    );
  }
}

// ── Animated checkbox ─────────────────────────────────────────────────────────

class _AnimatedCheckbox extends StatelessWidget {
  const _AnimatedCheckbox({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: checked ? AppColors.primary : AppColors.textDisabled,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
    );
  }
}

// ── Mini cover thumbnail ──────────────────────────────────────────────────────

class _PlaylistMiniCover extends StatelessWidget {
  const _PlaylistMiniCover({required this.playlist});
  final PlaylistItem playlist;

  @override
  Widget build(BuildContext context) {
    if (playlist.songs.isEmpty) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
          ),
        ),
        child: const Icon(
          Icons.playlist_play_rounded,
          color: Colors.white,
          size: 22,
        ),
      );
    }

    // Hiển thị album art của bài đầu
    return SizedBox(
      width: 46,
      height: 46,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: QueryArtworkWidget(
          id: playlist.songs.first.albumId,
          type: ArtworkType.ALBUM,
          artworkFit: BoxFit.cover,
          artworkBorder: BorderRadius.zero,
          keepOldArtwork: true,
          nullArtworkWidget: Container(
            color: AppColors.surfaceElevated,
            child: const Icon(
              Icons.queue_music_rounded,
              color: AppColors.textDisabled,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}