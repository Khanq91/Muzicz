import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/screens/playlist_screen.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/mini_player.dart';
import '../widgets/music_list_tile.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _searchActive = false;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Chào buổi sáng';
    if (h < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _buildHeader(),
                ),
                // Sticky search bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SearchBarDelegate(
                    searchCtrl: _searchCtrl,
                    onChanged: (q) {
                      context.read<MusicProvider>().setSearchQuery(q);
                      setState(() => _searchActive = q.isNotEmpty);
                    },
                    onClear: () {
                      _searchCtrl.clear();
                      context.read<MusicProvider>().setSearchQuery('');
                      setState(() => _searchActive = false);
                    },
                  ),
                ),
                // Search results or home content
                if (_searchActive)
                  _SearchResultsSliver(
                    onSongTap: (songs, song) => _playSong(songs, song),
                  )
                else ...[
                  // Quick Access
                  SliverToBoxAdapter(child: _QuickAccessSection()),
                  // Smart Lists
                  SliverToBoxAdapter(child: _SmartListsSection(
                    onSongTap: (songs, song) => _playSong(songs, song),
                  )),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ],
            ),
          ),
          // Mini player
          Consumer<PlayerProvider>(
            builder: (_, player, __) =>
                player.currentSong != null ? const MiniPlayer() : const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  'Muzicz Audio',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            _AvatarButton(),
          ],
        ),
      ),
    );
  }

  void _playSong(List<SongItem> songs, SongItem song) {
    context.read<PlayerProvider>().playSongs(songs, specificSong: song);
    context.read<MusicProvider>().onSongPlayed(song.id);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const NowPlayingScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }
}

// ── Search bar persistent delegate ──────────────────────────────────────

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  const _SearchBarDelegate({
    required this.searchCtrl,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController searchCtrl;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext _, double shrinkOffset, bool overlapsContent) {
    final elevated = shrinkOffset > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: elevated
          ? AppColors.background.withOpacity(0.95)
          : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: searchCtrl,
        onChanged: onChanged,
        style: GoogleFonts.outfit(
          color: AppColors.textPrimary,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'Tìm bài hát, nghệ sĩ, album…',
          hintStyle: GoogleFonts.outfit(
            color: AppColors.textDisabled,
            fontSize: 15,
          ),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textTertiary, size: 22),
          suffixIcon: searchCtrl.text.isNotEmpty
              ? GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.textTertiary, size: 20),
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceElevated,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 64;

  @override
  double get minExtent => 64;

  @override
  bool shouldRebuild(covariant _SearchBarDelegate old) => true;
}

// ── Search results ───────────────────────────────────────────────────────

class _SearchResultsSliver extends StatelessWidget {
  const _SearchResultsSliver({required this.onSongTap});
  final void Function(List<SongItem>, SongItem) onSongTap;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<PlayerProvider>();
    final results = music.filteredSongs;

    if (results.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded,
                  color: AppColors.textDisabled, size: 48),
              const SizedBox(height: 12),
              Text(
                'Không tìm thấy kết quả',
                style: GoogleFonts.outfit(
                  color: AppColors.textTertiary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final song = results[i];
          return MusicListTile(
            song: song,
            isActive: player.currentSong?.id == song.id,
            onTap: () => onSongTap(results, song),
          );
        },
        childCount: results.length,
      ),
    );
  }
}

// ── Quick Access Section ─────────────────────────────────────────────────

class _QuickAccessSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();

    final sections = [
      _QuickSection(
        title: 'Nghe gần đây',
        songs: music.recentlyPlayed,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
        icon: Icons.history_rounded,
      ),
      _QuickSection(
        title: 'Nghe nhiều nhất',
        songs: music.mostPlayed,
        gradient: const LinearGradient(
          colors: [Color(0xFFE040FB), AppColors.secondary],
        ),
        icon: Icons.trending_up_rounded,
      ),
      _QuickSection(
        title: 'Yêu thích',
        songs: music.favorites,
        gradient: const LinearGradient(
          colors: [AppColors.tertiary, Color(0xFFE91E63)],
        ),
        icon: Icons.favorite_rounded,
      ),
      _QuickSection(
        title: 'Random Mix',
        songs: music.randomMix,
        gradient: const LinearGradient(
          colors: [Color(0xFF00BCD4), AppColors.primary],
        ),
        icon: Icons.shuffle_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            'Truy cập nhanh',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sections.length,
            itemBuilder: (_, i) => _QuickCard(section: sections[i]),
          ),
        ),
      ],
    );
  }
}

class _QuickSection {
  final String title;
  final List<SongItem> songs;
  final LinearGradient gradient;
  final IconData icon;
  const _QuickSection(
      {required this.title,
      required this.songs,
      required this.gradient,
      required this.icon});
}

class _QuickCard extends StatefulWidget {
  const _QuickCard({required this.section});
  final _QuickSection section;

  @override
  State<_QuickCard> createState() => _QuickCardState();
}

class _QuickCardState extends State<_QuickCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    final songCount = s.songs.length;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) async {
        await _ctrl.reverse();
        if (s.songs.isEmpty) return;
        final player = context.read<PlayerProvider>();
        final music = context.read<MusicProvider>();
        player.playSongs(s.songs);
        music.onSongPlayed(s.songs.first.id);
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 140,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: s.gradient,
          ),
          child: Stack(
            children: [
              // Album art mosaic (first song)
              if (s.songs.isNotEmpty)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Opacity(
                      opacity: 0.25,
                      child: QueryArtworkWidget(
                        id: s.songs.first.albumId,
                        type: ArtworkType.ALBUM,
                        artworkFit: BoxFit.cover,
                        artworkBorder: BorderRadius.zero,
                        nullArtworkWidget: const SizedBox.shrink(),
                        keepOldArtwork: true,
                      ),
                    ),
                  ),
                ),
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.5),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(s.icon, color: Colors.white.withOpacity(0.9), size: 28),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '$songCount bài',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Smart Lists Section ──────────────────────────────────────────────────

class _SmartListsSection extends StatelessWidget {
  const _SmartListsSection({required this.onSongTap});
  final void Function(List<SongItem>, SongItem) onSongTap;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<PlayerProvider>();

    final recentlyAdded = music.recentlyAdded;
    final neverPlayed = music.neverPlayed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recentlyAdded.isNotEmpty) ...[
          _SectionHeader(title: 'Mới thêm gần đây'),
          ...recentlyAdded.take(5).map((song) => MusicListTile(
                key: ValueKey('ra_${song.id}'),
                song: song,
                isActive: player.currentSong?.id == song.id,
                onTap: () => onSongTap(recentlyAdded, song),
              )),
        ],
        if (neverPlayed.isNotEmpty) ...[
          _SectionHeader(title: 'Chưa từng nghe'),
          ...neverPlayed.take(5).map((song) => MusicListTile(
                key: ValueKey('np_${song.id}'),
                song: song,
                isActive: player.currentSong?.id == song.id,
                onTap: () => onSongTap(neverPlayed, song),
              )),
        ],
        if (recentlyAdded.isEmpty && neverPlayed.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(Icons.music_off_rounded,
                      color: AppColors.textDisabled, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có nhạc nào.\nHãy quét thư viện nhạc của bạn.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ── Avatar button ────────────────────────────────────────────────────────

class _AvatarButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.tertiary],
          ),
        ),
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}

// ── Bottom Nav ───────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        color: AppColors.background,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              active: true,
              onTap: () {},
            ),
            _NavItem(
              icon: Icons.library_music_rounded,
              label: 'Thư viện',
              active: false,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LibraryScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: active ? AppColors.primary : AppColors.textTertiary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? AppColors.primary : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
