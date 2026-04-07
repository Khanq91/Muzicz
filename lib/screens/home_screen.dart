import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/screens/playlist_screen.dart';
import 'package:muziczz/theme/app_colors_data.dart';
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
import 'online_screen.dart';
import 'onboarding_screen.dart';
import 'profile_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
// HomeScreen
// ════════════════════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _tabs = [
    _HomeTabBody(),
    OnlineScreen(isEmbedded: true),
    LibraryScreen(isEmbedded: true),
  ];

  @override
  Widget build(BuildContext context) {
  final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _tabs,
            ),
          ),
          Consumer<PlayerProvider>(
            builder: (_, player, __) => player.currentSong != null
                ? const RepaintBoundary(child: MiniPlayer())
                : const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _HomeTabBody
// ════════════════════════════════════════════════════════════════════════════

class _HomeTabBody extends StatefulWidget {
  const _HomeTabBody();

  @override
  State<_HomeTabBody> createState() => _HomeTabBodyState();
}

class _HomeTabBodyState extends State<_HomeTabBody> {
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
    final c = context.appColors;
    return CustomScrollView(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SearchBarDelegate(
            searchCtrl: _searchCtrl,
            onChanged: (q) {
              context.read<MusicProvider>().setHomeSearchQuery(q);
              setState(() => _searchActive = q.isNotEmpty);
            },
            onClear: () {
              _searchCtrl.clear();
              context.read<MusicProvider>().setHomeSearchQuery('');
              setState(() => _searchActive = false);
            },
          ),
        ),
        if (_searchActive)
          _SearchResultsSliver(
            onSongTap: (songs, song) => _playSong(songs, song),
          )
        else ...[
          SliverToBoxAdapter(
            child: RepaintBoundary(child: _QuickAccessSection()),
          ),
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: _SmartListsSection(
                onSongTap: (songs, song) => _playSong(songs, song),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    final music = context.watch<MusicProvider>();
    final isScanning = music.status == LibraryStatus.scanning;
    final c = context.appColors;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Greeting + title
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: c.textTertiary,
                  ),
                ),
                Text(
                  'Muzicz Audio',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // FIX 2: Nút scan — chỉ hiện sau lần quét đầu tiên
                if (music.hasScannedOnce)
                  _ScanButton(isScanning: isScanning),

                const SizedBox(width: 4),
                _AvatarButton(),
              ],
            ),
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

// ── Scan button cạnh avatar ───────────────────────────────────────────────────

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.isScanning});
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SizedBox(
      width: 40,
      height: 40,
      child: isScanning
          ? Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: c.primary,
          ),
        ),
      )
          : IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.refresh_rounded,
          color: c.textTertiary,
          size: 22,
        ),
        tooltip: 'Quét lại nhạc',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const OnboardingScreen(),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Bottom Navigation
// ════════════════════════════════════════════════════════════════════════════

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final c = context.appColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: c.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.30),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: c.primary.withOpacity(0.06),
              blurRadius: 32,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              active: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.language_rounded,
              label: 'Trực tuyến',
              active: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.library_music_rounded,
              label: 'Thư viện',
              active: currentIndex == 2,
              onTap: () => onTap(2),
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
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: active ? 16 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: active
              ? c.primary.withOpacity(0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Icon(
                icon,
                color: active ? c.primary : c.textTertiary,
                size: 22,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: active
                  ? Padding(
                padding: const EdgeInsets.only(left: 7),
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.primary,
                  ),
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final elevated = shrinkOffset > 0;
    final c = context.appColors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: elevated
          ? c.background.withOpacity(0.95)
          : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: searchCtrl,
        onChanged: onChanged,
        style: GoogleFonts.outfit(
          color: c.textPrimary,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'Tìm bài hát, nghệ sĩ, album…',
          hintStyle: GoogleFonts.outfit(
            color: c.textDisabled,
            fontSize: 15,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: c.textTertiary, size: 22),
          suffixIcon: searchCtrl.text.isNotEmpty
              ? GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close_rounded,
                color: c.textTertiary, size: 20),
          )
              : null,
          filled: true,
          fillColor: c.surfaceElevated,
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
            borderSide: BorderSide(color: c.primary, width: 1),
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

// ── Search results ────────────────────────────────────────────────────────────

class _SearchResultsSliver extends StatelessWidget {
  const _SearchResultsSliver({required this.onSongTap});
  final void Function(List<SongItem>, SongItem) onSongTap;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<PlayerProvider>();
    final results = music.filteredSongs;
    final c = context.appColors;
    if (results.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  color: c.textDisabled, size: 48),
              const SizedBox(height: 12),
              Text(
                'Không tìm thấy kết quả',
                style: GoogleFonts.outfit(
                  color: c.textTertiary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Thử tìm bằng tên nghệ sĩ hoặc album',
                style: GoogleFonts.outfit(
                  color: c.textDisabled,
                  fontSize: 13,
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

// ── Quick Access ──────────────────────────────────────────────────────────────

class _QuickAccessSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final c = context.appColors;
    final sections = [
      _QuickSection(
        title: 'Nghe gần đây',
        songs: music.recentlyPlayed,
        gradient: c.recentlyPlayedGradient,
        icon: Icons.history_rounded,
      ),
      _QuickSection(
        title: 'Nghe nhiều nhất',
        songs: music.mostPlayed,
        gradient: c.mostPlayedGradient,
        icon: Icons.trending_up_rounded,
      ),
      _QuickSection(
        title: 'Yêu thích',
        songs: music.favorites,
        gradient: c.favoritesGradient,
        icon: Icons.favorite_rounded,
      ),
      _QuickSection(
        title: 'Random Mix',
        songs: music.randomMix,
        gradient: c.randomMixGradient,
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
              color: c.textPrimary,
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
  const _QuickSection({
    required this.title,
    required this.songs,
    required this.gradient,
    required this.icon,
  });
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
    final c = context.appColors;

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
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        c.scrimMedium,
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
                    Icon(s.icon,
                        color: Colors.white.withOpacity(0.9), size: 28),
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

// ── Smart Lists Section ───────────────────────────────────────────────────────

class _SmartListsSection extends StatelessWidget {
  const _SmartListsSection({required this.onSongTap});
  final void Function(List<SongItem>, SongItem) onSongTap;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<PlayerProvider>();
    final recentlyAdded = music.recentlyAdded;
    final neverPlayed = music.neverPlayed;
    final c = context.appColors;
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
        // FIX 2: Empty state với nút quét — hướng user rõ ràng hơn
        if (recentlyAdded.isEmpty && neverPlayed.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 40, 40, 20),
              child: Column(
                children: [
                  Icon(Icons.music_off_rounded,
                      color: c.textDisabled, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có nhạc nào.\nHãy quét thư viện nhạc của bạn.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: c.textTertiary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(
                      'Quét thư viện ngay',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [c.primary, c.tertiary],
          ),
        ),
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}