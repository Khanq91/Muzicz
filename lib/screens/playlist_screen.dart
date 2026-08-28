import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/utils/duration_format.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/playlist_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/music_list_tile.dart';
import 'now_playing_screen.dart';
import 'package:muziczz/core/app_strings.dart';

/// Tab content: list of all playlists
class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final playlists = music.playlists;
    final c = context.appColors;
    return Stack(
      children: [
        playlists.isEmpty
            ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.playlist_play_rounded,
                    color: c.textDisabled,
                    size: 52,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppStrings.noPlaylistsCreateHint,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: c.textTertiary,
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
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => PlaylistDetailScreen(playlistId: pl.id),
                        ),
                      ),
                  onDelete: () => _confirmDelete(context, music, pl),
                );
              },
            ),
        // FAB: create new playlist
        Positioned(bottom: 16, right: 16, child: _CreatePlaylistFab()),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MusicProvider music,
    PlaylistItem pl,
  ) async {
    final c = context.appColors;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              AppStrings.deletePlaylistTitle(pl.name),
              style: GoogleFonts.outfit(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              AppStrings.deletePlaylistBody,
              style: GoogleFonts.outfit(
                color: c.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  AppStrings.cancel,
                  style: GoogleFonts.outfit(color: c.textTertiary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  AppStrings.delete,
                  style: GoogleFonts.outfit(
                    color: c.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
    if (ok != true) return;
    await music.deletePlaylist(pl.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.deletedPlaylist(pl.name),
          style: GoogleFonts.outfit(fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: context.appColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
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
    final c = context.appColors;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: _PlaylistCover(playlist: playlist, size: 52),
      title: Text(
        playlist.name,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
      ),
      subtitle: Text(
        AppStrings.playlistMeta(
          playlist.songCount,
          playlist.totalDuration.compact,
        ),
        style: GoogleFonts.outfit(fontSize: 12, color: c.textTertiary),
      ),
      trailing: PopupMenuButton<String>(
        color: c.card,
        icon: Icon(Icons.more_vert_rounded, color: c.textTertiary, size: 20),
        onSelected: (val) {
          if (val == 'delete') onDelete();
        },
        itemBuilder:
            (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: c.tertiary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppStrings.delete,
                      style: GoogleFonts.outfit(
                        color: c.tertiary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
      ),
      onTap: onTap,
    );
  }
}

// ── Playlist cover ────────────────────────────────────────

class _PlaylistCover extends StatelessWidget {
  const _PlaylistCover({required this.playlist, this.size = 52});
  final PlaylistItem playlist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // Custom image
    if (playlist.coverPath != null) {
      // Camera photos can be 12MP; decode at the cell's physical size
      // (x2 so a landscape photo still fills the square after the cover
      // crop) instead of the original resolution.
      final cacheWidth =
          (size * MediaQuery.devicePixelRatioOf(context) * 2).round();
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(playlist.coverPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
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
          gradient: LinearGradient(colors: [c.primary, c.secondary]),
        ),
        child: Icon(
          Icons.playlist_play_rounded,
          color: c.onPlayer,
          size: size * 0.5,
        ),
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
          nullArtworkWidget: _defaultCover(context, size),
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
              return Container(color: c.surfaceElevated);
            }
            return QueryArtworkWidget(
              id: songs[i].albumId,
              type: ArtworkType.ALBUM,
              artworkFit: BoxFit.cover,
              artworkBorder: BorderRadius.zero,
              keepOldArtwork: true,
              nullArtworkWidget: Container(color: c.surfaceElevated),
            );
          }),
        ),
      ),
    );
  }

  // Widget _defaultCover(double size) => Container(
  //   color: AppColors.surfaceElevated,
  //   child: Icon(Icons.music_note_rounded,
  //       color: AppColors.textDisabled, size: size * 0.4),
  // );
  Widget _defaultCover(BuildContext context, double size) {
    final c = context.appColors;
    return Container(
      color: c.surfaceElevated,
      child: Icon(
        Icons.music_note_rounded,
        color: c.textDisabled,
        size: size * 0.4,
      ),
    );
  }
}

// ── FAB create playlist ───────────────────────────────────

class _CreatePlaylistFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: () => _showCreateDialog(context),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: c.primaryGradient,
          boxShadow: [
            BoxShadow(color: c.primary, blurRadius: 16, offset: Offset(0, 4)),
          ],
        ),
        child: Icon(Icons.add_rounded, color: c.onPlayer, size: 28),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final c = context.appColors;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              AppStrings.createPlaylist,
              style: GoogleFonts.outfit(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.outfit(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: AppStrings.playlistNameHint,
                hintStyle: GoogleFonts.outfit(color: c.textDisabled),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppStrings.cancel,
                  style: GoogleFonts.outfit(color: c.textTertiary),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) return;
                  await context.read<MusicProvider>().createPlaylist(name);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(
                  AppStrings.create,
                  style: GoogleFonts.outfit(
                    color: c.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    ).whenComplete(ctrl.dispose);
  }
}

// ── Playlist detail screen ────────────────────────────────

class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});
  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    // Player state is only rendered per tile (isActive); read it here so a
    // play/pause, track change or sleep-timer tick does not rebuild the
    // SliverAppBar, header image, buttons and the whole list.
    final player = context.read<PlayerProvider>();
    final playlist = music.playlists.firstWhere((p) => p.id == playlistId);
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: c.background,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: c.onPlayer,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.edit_rounded, color: c.onPlayer, size: 22),
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
                        label: AppStrings.playAll,
                        icon: Icons.play_arrow_rounded,
                        onTap: () {
                          player.playSongs(playlist.songs);
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder:
                                  (_, anim, __) => const NowPlayingScreen(),
                              transitionDuration: const Duration(
                                milliseconds: 400,
                              ),
                              transitionsBuilder:
                                  (_, anim, __, child) => SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 1),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: anim,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    ),
                                    child: child,
                                  ),
                            ),
                          );
                        },
                        primary: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PlayButton(
                        label: AppStrings.shuffle,
                        icon: Icons.shuffle_rounded,
                        onTap: () async {
                          await player.playSongsShuffled(playlist.songs);
                          if (context.mounted) {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder:
                                    (_, anim, __) => const NowPlayingScreen(),
                                transitionDuration: const Duration(
                                  milliseconds: 400,
                                ),
                                transitionsBuilder:
                                    (_, anim, __, child) => SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 1),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: anim,
                                          curve: Curves.easeOutCubic,
                                        ),
                                      ),
                                      child: child,
                                    ),
                              ),
                            );
                          }
                        },
                        primary: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _PlayButton(
                      label: AppStrings.shuffleLoop,
                      icon: Icons.all_inclusive_rounded,
                      onTap: () async {
                        await player.enableShuffleLoop(playlist.songs);
                        if (context.mounted) {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder:
                                  (_, anim, __) => const NowPlayingScreen(),
                              transitionDuration: const Duration(
                                milliseconds: 400,
                              ),
                              transitionsBuilder:
                                  (_, anim, __, child) => SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 1),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: anim,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    ),
                                    child: child,
                                  ),
                            ),
                          );
                        }
                      },
                      primary: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Nút info
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (_) => AlertDialog(
                              backgroundColor: c.card,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.all_inclusive_rounded,
                                    color: c.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppStrings.shuffleLoop,
                                    style: GoogleFonts.outfit(
                                      color: c.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              content: Text(
                                AppStrings.shuffleLoopDescription,
                                style: GoogleFonts.outfit(
                                  color: c.textSecondary,
                                  fontSize: 14,
                                  height: 1.6,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    AppStrings.ok,
                                    style: GoogleFonts.outfit(
                                      color: c.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 46,
                      decoration: BoxDecoration(
                        color: c.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border, width: 0.5),
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: c.textTertiary,
                        size: 20,
                      ),
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
                    AppStrings.songCount(playlist.songCount),
                    style: GoogleFonts.outfit(
                      color: c.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showAddSongsSheet(context, music, playlist),
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, color: c.primary, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          AppStrings.addSongs,
                          style: GoogleFonts.outfit(
                            color: c.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
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
                    Icon(
                      Icons.music_note_rounded,
                      color: c.textDisabled,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.emptyPlaylistHint,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: c.textTertiary,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((_, i) {
                final song = playlist.songs[i];
                return Selector<PlayerProvider, int?>(
                  selector: (_, p) => p.currentSong?.id,
                  builder:
                      (_, activeId, __) => MusicListTile(
                        song: song,
                        isActive: activeId == song.id,
                        onTap: () {
                          player.playSongs(playlist.songs, specificSong: song);
                          music.onSongPlayed(song.id);
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder:
                                  (_, anim, __) => const NowPlayingScreen(),
                              transitionDuration: const Duration(
                                milliseconds: 400,
                              ),
                              transitionsBuilder:
                                  (_, anim, __, child) => SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 1),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: anim,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    ),
                                    child: child,
                                  ),
                            ),
                          );
                        },
                        trailing: GestureDetector(
                          onTap: () {
                            music.removeFromPlaylist(playlistId, song.id);
                          },
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.remove_circle_outline_rounded,
                              color: c.textDisabled,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                );
              }, childCount: playlist.songs.length),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    MusicProvider music,
    PlaylistItem playlist,
  ) {
    final ctrl = TextEditingController(text: playlist.name);
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
              AppStrings.rename,
              style: GoogleFonts.outfit(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: TextField(
              controller: ctrl,
              autofocus: true,
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
                  final name = ctrl.text.trim();
                  if (name.isNotEmpty) {
                    music.renamePlaylist(playlistId, name);
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  AppStrings.save,
                  style: GoogleFonts.outfit(
                    color: c.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    ).whenComplete(ctrl.dispose);
  }

  void _showAddSongsSheet(
    BuildContext context,
    MusicProvider music,
    PlaylistItem playlist,
  ) {
    final c = context.appColors;
    final existingIds = playlist.songs.map((s) => s.id).toSet();
    final available =
        music.allSongs.where((s) => !existingIds.contains(s.id)).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.95,
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
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.addSongsTitle,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          available.isEmpty
                              ? Center(
                                child: Text(
                                  AppStrings.allSongsAlreadyInPlaylist,
                                  style: GoogleFonts.outfit(
                                    color: c.textTertiary,
                                  ),
                                ),
                              )
                              : ListView.builder(
                                controller: scrollCtrl,
                                itemCount: available.length,
                                itemBuilder: (ctx, i) {
                                  final song = available[i];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 2,
                                    ),
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
                                            color: c.surfaceElevated,
                                            child: Icon(
                                              Icons.music_note_rounded,
                                              color: c.textDisabled,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: c.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      song.artist,
                                      maxLines: 1,
                                      style: GoogleFonts.outfit(
                                        color: c.textTertiary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: Icon(
                                      Icons.add_rounded,
                                      color: c.primary,
                                    ),
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
    final c = context.appColors;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        Container(decoration: BoxDecoration(gradient: c.backgroundGradient)),
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
                c.background.withValues(alpha: 0.95),
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
                  color: c.onPlayer,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                AppStrings.songCount(playlist.songCount),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: c.onPlayerHigh,
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
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          gradient:
              primary
                  ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [c.primary, c.secondary],
                  )
                  : null,
          color: primary ? null : c.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: primary ? null : Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary ? c.onPlayer : c.textSecondary, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primary ? c.onPlayer : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
