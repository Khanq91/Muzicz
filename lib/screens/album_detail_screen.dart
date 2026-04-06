import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/music_list_tile.dart';
import 'now_playing_screen.dart';

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
    final music = context.watch<MusicProvider>();

    final albumId = songs.isNotEmpty ? songs.first.albumId : 0;
    final artistName = songs.isNotEmpty ? songs.first.artist : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero header ───────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: Colors.white),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Phát tất cả',
                      icon: Icons.play_arrow_rounded,
                      primary: true,
                      onTap: () {
                        player.playSongs(songs);
                        music.onSongPlayed(songs.first.id);
                        Navigator.of(context).push(_playerRoute());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      label: 'Ngẫu nhiên',
                      icon: Icons.shuffle_rounded,
                      primary: false,
                      onTap: () async {
                        await player.playSongs(songs);
                        await player.toggleShuffle();
                        if (context.mounted) {
                          Navigator.of(context).push(_playerRoute());
                        }
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
                '${songs.length} bài hát',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),

          // ── Song list ─────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (_, i) {
                final song = songs[i];
                return MusicListTile(
                  song: song,
                  isActive: player.currentSong?.id == song.id,
                  onTap: () {
                    player.playSongs(songs, specificSong: song);
                    music.onSongPlayed(song.id);
                    Navigator.of(context).push(_playerRoute());
                  },
                );
              },
              childCount: songs.length,
            ),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        ),
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
                  AppColors.primary.withOpacity(0.4),
                  AppColors.secondary.withOpacity(0.4),
                ],
              ),
            ),
          ),
        ),
        // Dark overlay
        Container(color: Colors.black.withOpacity(0.50)),
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
                    color: Colors.black.withOpacity(0.5),
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
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: const Icon(Icons.album_rounded,
                        color: Colors.white54, size: 48),
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
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$artistName · $songCount bài hát',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white70,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary])
              : null,
          color: primary ? null : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border:
          primary ? null : Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: primary ? Colors.white : AppColors.textSecondary,
                size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primary ? Colors.white : AppColors.textSecondary,
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
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: child,
  ),
);