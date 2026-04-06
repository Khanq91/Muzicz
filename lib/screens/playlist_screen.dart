import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/playlist_item.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/music_list_tile.dart';
import 'now_playing_screen.dart';

/// Tab content: list of all playlists
class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final playlists = music.playlists;

    return Stack(
      children: [
        playlists.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.playlist_play_rounded,
                        color: AppColors.textDisabled, size: 52),
                    const SizedBox(height: 14),
                    Text(
                      'Chưa có danh sách phát nào.\nNhấn + để tạo mới.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: playlists.length,
                itemBuilder: (_, i) {
                  final pl = playlists[i];
                  return _PlaylistTile(
                    playlist: pl,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PlaylistDetailScreen(playlistId: pl.id),
                      ),
                    ),
                    onDelete: () => music.deletePlaylist(pl.id),
                  );
                },
              ),
        // FAB: create new playlist
        Positioned(
          bottom: 16,
          right: 16,
          child: _CreatePlaylistFab(),
        ),
      ],
    );
  }
}

// ── Playlist tile ─────────────────────────────────────────

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onDelete,
  });
  final PlaylistItem playlist;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: _PlaylistCover(playlist: playlist, size: 52),
      title: Text(
        playlist.name,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        '${playlist.songCount} bài · ${_fmtDuration(playlist.totalDuration)}',
        style: GoogleFonts.outfit(
            fontSize: 12, color: AppColors.textTertiary),
      ),
      trailing: PopupMenuButton<String>(
        color: AppColors.card,
        icon: const Icon(Icons.more_vert_rounded,
            color: AppColors.textTertiary, size: 20),
        onSelected: (val) {
          if (val == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline_rounded,
                    color: AppColors.tertiary, size: 20),
                const SizedBox(width: 12),
                Text('Xóa',
                    style: GoogleFonts.outfit(
                        color: AppColors.tertiary, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }
}

// ── Playlist cover ────────────────────────────────────────

class _PlaylistCover extends StatelessWidget {
  const _PlaylistCover({required this.playlist, this.size = 52});
  final PlaylistItem playlist;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Custom image
    if (playlist.coverPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(playlist.coverPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    // Grid of up to 4 album arts
    final songs = playlist.songs.take(4).toList();
    if (songs.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
          ),
        ),
        child: Icon(Icons.playlist_play_rounded,
            color: AppColors.onPlayer, size: size * 0.5),
      );
    }
    if (songs.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: QueryArtworkWidget(
          id: songs[0].albumId,
          type: ArtworkType.ALBUM,
          artworkFit: BoxFit.cover,
          artworkBorder: BorderRadius.zero,
          keepOldArtwork: true,
          artworkWidth: size,
          artworkHeight: size,
          nullArtworkWidget: _defaultCover(size),
        ),
      );
    }
    // 2x2 grid
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(4, (i) {
            if (i >= songs.length) {
              return Container(color: AppColors.surfaceElevated);
            }
            return QueryArtworkWidget(
              id: songs[i].albumId,
              type: ArtworkType.ALBUM,
              artworkFit: BoxFit.cover,
              artworkBorder: BorderRadius.zero,
              keepOldArtwork: true,
              nullArtworkWidget:
                  Container(color: AppColors.surfaceElevated),
            );
          }),
        ),
      ),
    );
  }

  Widget _defaultCover(double size) => Container(
        color: AppColors.surfaceElevated,
        child: Icon(Icons.music_note_rounded,
            color: AppColors.textDisabled, size: size * 0.4),
      );
}

// ── FAB create playlist ───────────────────────────────────

class _CreatePlaylistFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCreateDialog(context),
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: AppColors.onPlayer, size: 28),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Tạo danh sách phát',
          style: GoogleFonts.outfit(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy',
                style:
                    GoogleFonts.outfit(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                context.read<MusicProvider>().createPlaylist(name);
                Navigator.pop(context);
              }
            },
            child: Text('Tạo',
                style: GoogleFonts.outfit(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Playlist detail screen ────────────────────────────────

class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});
  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<PlayerProvider>();
    final playlist =
        music.playlists.firstWhere((p) => p.id == playlistId);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: AppColors.onPlayer),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded,
                    color: AppColors.onPlayer, size: 22),
                onPressed: () => _showEditDialog(context, music, playlist),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _PlaylistHeader(playlist: playlist),
            ),
          ),
          // Play all button
          if (playlist.songs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _PlayButton(
                        label: 'Phát tất cả',
                        icon: Icons.play_arrow_rounded,
                        onTap: () {
                          player.playSongs(playlist.songs);
                          Navigator.of(context).push(PageRouteBuilder(
                            pageBuilder: (_, anim, __) =>
                                const NowPlayingScreen(),
                            transitionDuration:
                                const Duration(milliseconds: 400),
                            transitionsBuilder: (_, anim, __, child) =>
                                SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                  parent: anim,
                                  curve: Curves.easeOutCubic)),
                              child: child,
                            ),
                          ));
                        },
                        primary: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PlayButton(
                        label: 'Ngẫu nhiên',
                        icon: Icons.shuffle_rounded,
                        onTap: () async {
                          await player.playSongs(playlist.songs);
                          await player.toggleShuffle();
                        },
                        primary: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Song list with reorder
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${playlist.songCount} bài hát',
                    style: GoogleFonts.outfit(
                        color: AppColors.textTertiary, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () => _showAddSongsSheet(
                        context, music, playlist),
                    child: Row(
                      children: [
                        const Icon(Icons.add_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'Thêm bài',
                          style: GoogleFonts.outfit(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (playlist.songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.music_note_rounded,
                        color: AppColors.textDisabled, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Danh sách trống.\nNhấn "Thêm bài" để bắt đầu.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          color: AppColors.textTertiary,
                          fontSize: 14,
                          height: 1.6),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final song = playlist.songs[i];
                  return MusicListTile(
                    song: song,
                    isActive: player.currentSong?.id == song.id,
                    onTap: () {
                      player.playSongs(playlist.songs, specificSong: song);
                      music.onSongPlayed(song.id);
                      Navigator.of(context).push(PageRouteBuilder(
                        pageBuilder: (_, anim, __) =>
                            const NowPlayingScreen(),
                        transitionDuration:
                            const Duration(milliseconds: 400),
                        transitionsBuilder: (_, anim, __, child) =>
                            SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                      ));
                    },
                    trailing: GestureDetector(
                      onTap: () {
                        music.removeFromPlaylist(playlistId, song.id);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.remove_circle_outline_rounded,
                            color: AppColors.textDisabled, size: 20),
                      ),
                    ),
                  );
                },
                childCount: playlist.songs.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, MusicProvider music, PlaylistItem playlist) {
    final ctrl = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Đổi tên',
            style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.outfit(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy',
                style: GoogleFonts.outfit(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                music.renamePlaylist(playlistId, name);
                Navigator.pop(context);
              }
            },
            child: Text('Lưu',
                style: GoogleFonts.outfit(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAddSongsSheet(
      BuildContext context, MusicProvider music, PlaylistItem playlist) {
    final existingIds = playlist.songs.map((s) => s.id).toSet();
    final available = music.allSongs
        .where((s) => !existingIds.contains(s.id))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Thêm bài hát',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: available.isEmpty
                  ? Center(
                      child: Text(
                        'Tất cả bài hát đã có trong danh sách.',
                        style: GoogleFonts.outfit(
                            color: AppColors.textTertiary),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: available.length,
                      itemBuilder: (ctx, i) {
                        final song = available[i];
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 2),
                          leading: SizedBox(
                            width: 44,
                            height: 44,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: QueryArtworkWidget(
                                id: song.albumId,
                                type: ArtworkType.ALBUM,
                                artworkFit: BoxFit.cover,
                                artworkBorder: BorderRadius.zero,
                                keepOldArtwork: true,
                                nullArtworkWidget: Container(
                                  color: AppColors.surfaceElevated,
                                  child: const Icon(
                                      Icons.music_note_rounded,
                                      color: AppColors.textDisabled,
                                      size: 20),
                                ),
                              ),
                            ),
                          ),
                          title: Text(song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(song.artist,
                              maxLines: 1,
                              style: GoogleFonts.outfit(
                                  color: AppColors.textTertiary,
                                  fontSize: 12)),
                          trailing: const Icon(Icons.add_rounded,
                              color: AppColors.primary),
                          onTap: () {
                            music.addToPlaylist(playlist.id, song);
                            Navigator.pop(context);
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
}

// ── Playlist header ───────────────────────────────────────

class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({required this.playlist});
  final PlaylistItem playlist;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        Container(
          decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        ),
        // Cover image or generated mosaic
        if (playlist.coverPath != null)
          Image.file(File(playlist.coverPath!), fit: BoxFit.cover)
        else if (playlist.songs.isNotEmpty)
          Opacity(
            opacity: 0.4,
            child: QueryArtworkWidget(
              id: playlist.songs.first.albumId,
              type: ArtworkType.ALBUM,
              artworkFit: BoxFit.cover,
              artworkBorder: BorderRadius.zero,
              keepOldArtwork: true,
              nullArtworkWidget: const SizedBox.shrink(),
            ),
          ),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                AppColors.background.withOpacity(0.95),
              ],
            ),
          ),
        ),
        // Info
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playlist.name,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPlayer,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '${playlist.songCount} bài hát',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.onPlayerHigh,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Play button row ───────────────────────────────────────

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          gradient: primary ? const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.primary, AppColors.secondary],
          ) : null,
          color: primary ? null : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: primary
              ? null
              : Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: primary ? AppColors.onPlayer : AppColors.textSecondary,
                size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primary ? AppColors.onPlayer : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
