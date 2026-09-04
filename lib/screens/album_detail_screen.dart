import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_item.dart';
import '../providers/player_provider.dart';
import '../widgets/music_list_tile.dart';
import 'now_playing_screen.dart';
import 'package:muziczz/core/app_strings.dart';

class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({
    super.key,
    required this.albumName,
    required this.songs,
  });

  final String albumName;
  final List<SongItem> songs;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    final albumId = songs.isNotEmpty ? songs.first.albumId : 0;
    final artistName = songs.isNotEmpty ? songs.first.artist : '';

    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero header ───────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: c.background,
            leading: IconButton(
              tooltip: AppStrings.back,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: c.onPlayer,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _AlbumHeader(
                albumId: albumId,
                albumName: albumName,
                artistName: artistName,
                songCount: songs.length,
              ),
            ),
          ),

          // ── Play all + Shuffle ────────────────────────────────
          // Sau
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: AppStrings.playAll,
                      icon: Icons.play_arrow_rounded,
                      primary: true,
                      onTap: () {
                        player.playSongs(songs);
                        Navigator.of(context).push(_playerRoute());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      label: AppStrings.shuffle,
                      icon: Icons.shuffle_rounded,
                      primary: false,
                      onTap: () {
                        player.playSongsShuffled(songs);
                        Navigator.of(context).push(_playerRoute());
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Thêm SliverToBoxAdapter mới ngay sau
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: AppStrings.shuffleLoop,
                      icon: Icons.all_inclusive_rounded,
                      primary: false,
                      onTap: () {
                        player.enableShuffleLoop(songs);
                        Navigator.of(context).push(_playerRoute());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final c = context.appColors;
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
                    child: Builder(
                      builder: (context) {
                        final c = context.appColors;
                        return Semantics(
                          button: true,
                          label: AppStrings.shuffleLoopInfo,
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
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Song count header ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                AppStrings.songCount(songs.length),
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: c.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),

          // ── Song list ─────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final song = songs[i];
              return MusicListTile(
                song: song,
                isActive: player.currentSong?.id == song.id,
                onTap: () {
                  player.playSongs(songs, specificSong: song);
                  Navigator.of(context).push(_playerRoute());
                },
              );
            }, childCount: songs.length),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Album header ──────────────────────────────────────────────────────────────

class _AlbumHeader extends StatelessWidget {
  const _AlbumHeader({
    required this.albumId,
    required this.albumName,
    required this.artistName,
    required this.songCount,
  });
  final int albumId;
  final String albumName;
  final String artistName;
  final int songCount;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient
        Container(decoration: BoxDecoration(gradient: c.backgroundGradient)),
        // Album art full-bleed (blurred)
        QueryArtworkWidget(
          id: albumId,
          type: ArtworkType.ALBUM,
          artworkFit: BoxFit.cover,
          artworkBorder: BorderRadius.zero,
          keepOldArtwork: true,
          artworkQuality: FilterQuality.low,
          nullArtworkWidget: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.primary.withValues(alpha: 0.4),
                  c.secondary.withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
        ),
        // Dark overlay
        Container(color: c.scrimMedium),
        // Center album art (sharp)
        Positioned(
          top: 52,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: QueryArtworkWidget(
                  id: albumId,
                  type: ArtworkType.ALBUM,
                  artworkFit: BoxFit.cover,
                  artworkBorder: BorderRadius.zero,
                  keepOldArtwork: true,
                  nullArtworkWidget: Container(
                    decoration: BoxDecoration(gradient: c.primaryGradient),
                    child: Icon(
                      Icons.album_rounded,
                      color: c.onPlayerLow,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Info text
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                albumName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: c.onPlayer,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.albumHeaderSubtitle(artistName, songCount),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
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

// ── Action buttons — tái dụng pattern từ ArtistDetailScreen ──────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          gradient:
              primary ? LinearGradient(colors: [c.primary, c.secondary]) : null,
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

PageRouteBuilder _playerRoute() => PageRouteBuilder(
  pageBuilder: (_, anim, __) => const NowPlayingScreen(),
  transitionDuration: const Duration(milliseconds: 400),
  transitionsBuilder:
      (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
);
