import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/music_list_tile.dart';
import 'now_playing_screen.dart';

class ArtistDetailScreen extends StatelessWidget {
  const ArtistDetailScreen({
    super.key,
    required this.artistName,
    required this.songs,
  });

  final String artistName;
  final List<SongItem> songs;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final music = context.watch<MusicProvider>();
    final c = context.appColors;
    // Group songs by album
    final albumMap = <String, List<SongItem>>{};
    for (final s in songs) {
      albumMap.putIfAbsent(s.album, () => []).add(s);
    }

    final artistId = songs.first.artistId;

    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero header ──────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: c.background,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: c.onPlayer),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _ArtistHeader(
                artistId: artistId,
                artistName: artistName,
                songCount: songs.length,
                albumCount: albumMap.length,
              ),
            ),
          ),

          // ── Action buttons ────────────────────────────
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

          // ── Albums section ────────────────────────────
          if (albumMap.length > 1) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: Text(
                  'Album',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 148,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: albumMap.length,
                  itemBuilder: (_, i) {
                    final entry = albumMap.entries.toList()[i];
                    final albumId = entry.value.first.albumId;
                    return GestureDetector(
                      onTap: () {
                        player.playSongs(entry.value);
                        Navigator.of(context).push(_playerRoute());
                      },
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 120,
                                height: 100,
                                child: QueryArtworkWidget(
                                  id: albumId,
                                  type: ArtworkType.ALBUM,
                                  artworkFit: BoxFit.cover,
                                  artworkBorder: BorderRadius.zero,
                                  keepOldArtwork: true,
                                  artworkQuality: FilterQuality.low,
                                  nullArtworkWidget: Container(
                                    color: c.surfaceElevated,
                                    child: Icon(Icons.album_rounded,
                                        color: c.textDisabled,
                                        size: 32),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                              ),
                            ),
                            Text(
                              '${entry.value.length} bài',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: c.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // ── All songs ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Tất cả bài hát (${songs.length})',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ),
          ),
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

class _ArtistHeader extends StatelessWidget {
  const _ArtistHeader({
    required this.artistId,
    required this.artistName,
    required this.songCount,
    required this.albumCount,
  });
  final int artistId;
  final String artistName;
  final int songCount;
  final int albumCount;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        Container(
            decoration:
            BoxDecoration(gradient: c.backgroundGradient)),
        // Artist artwork (blurred bg)
        QueryArtworkWidget(
          id: artistId,
          type: ArtworkType.ARTIST,
          artworkFit: BoxFit.cover,
          artworkBorder: BorderRadius.zero,
          keepOldArtwork: true,
          nullArtworkWidget: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.primary.withOpacity(0.4),
                  c.secondary.withOpacity(0.4),
                ],
              ),
            ),
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: c.scrimLight),
        ),
        // Artist circle avatar
        Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: c.primary.withOpacity(0.3),
                      blurRadius: 20),
                ],
              ),
              child: ClipOval(
                child: QueryArtworkWidget(
                  id: artistId,
                  type: ArtworkType.ARTIST,
                  artworkFit: BoxFit.cover,
                  artworkBorder: BorderRadius.zero,
                  keepOldArtwork: true,
                  nullArtworkWidget: Container(
                    decoration: BoxDecoration(
                      gradient: c.primaryGradient,
                    ),
                    child: Center(
                      child: Text(
                        artistName.isNotEmpty
                            ? artistName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: c.onPlayer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Info
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Column(
            children: [
              Text(
                artistName,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: c.onPlayer,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$songCount bài hát · $albumCount album',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: c.onPlayerHigh,
                    fontWeight: FontWeight.w300),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
          gradient: primary
              ? LinearGradient(
              colors: [c.primary, c.secondary])
              : null,
          color: primary ? null : c.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border:
          primary ? null : Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: primary ? c.onPlayer : c.textSecondary,
                size: 20),
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
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(
        begin: const Offset(0, 1), end: Offset.zero)
        .animate(
        CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: child,
  ),
);