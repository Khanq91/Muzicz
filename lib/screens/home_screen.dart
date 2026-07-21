import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_bottom_navigation.dart';
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
    final bottomNavStyle = context.watch<ThemeProvider>().bottomNavStyle;
    return Scaffold(
      backgroundColor: c.background,
      body:
          bottomNavStyle.usesLiquidGlass
              ? Stack(
                children: [
                  Positioned.fill(
                    child: IndexedStack(index: _currentIndex, children: _tabs),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Consumer<PlayerProvider>(
                      builder:
                          (_, player, __) =>
                              player.currentSong != null
                                  ? const MiniPlayer()
                                  : const SizedBox.shrink(),
                    ),
                  ),
                ],
              )
              : Column(
                children: [
                  Expanded(
                    child: IndexedStack(index: _currentIndex, children: _tabs),
                  ),
                  Consumer<PlayerProvider>(
                    builder:
                        (_, player, __) =>
                            player.currentSong != null
                                ? const RepaintBoundary(child: MiniPlayer())
                                : const SizedBox.shrink(),
                  ),
                ],
              ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        style: bottomNavStyle,
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
    final music = context.watch<MusicProvider>();
    final isInitialScan =
        music.status == LibraryStatus.scanning && music.allSongs.isEmpty;

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
        else if (isInitialScan)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _InitialLibraryLoadingState(),
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
                if (music.hasScannedOnce) _ScanButton(isScanning: isScanning),

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
        transitionsBuilder:
            (_, anim, __, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
      ),
    );
  }
}

class _InitialLibraryLoadingState extends StatelessWidget {
  const _InitialLibraryLoadingState();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Semantics(
      key: const ValueKey('initial-library-loading'),
      liveRegion: true,
      label: 'Đang tải thư viện nhạc',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: c.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Đang tải thư viện nhạc…',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: c.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
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
      child:
          isScanning
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
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  );
                },
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
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final elevated = shrinkOffset > 0;
    final c = context.appColors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color:
          elevated ? c.background.withValues(alpha: 0.95) : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: searchCtrl,
        onChanged: onChanged,
        style: GoogleFonts.outfit(color: c.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Tìm bài hát, nghệ sĩ, album…',
          hintStyle: GoogleFonts.outfit(color: c.textDisabled, fontSize: 15),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: c.textTertiary,
            size: 22,
          ),
          suffixIcon:
              searchCtrl.text.isNotEmpty
                  ? GestureDetector(
                    onTap: onClear,
                    child: Icon(
                      Icons.close_rounded,
                      color: c.textTertiary,
                      size: 20,
                    ),
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
              Icon(Icons.search_off_rounded, color: c.textDisabled, size: 48),
              const SizedBox(height: 12),
              Text(
                'Không tìm thấy kết quả',
                style: GoogleFonts.outfit(color: c.textTertiary, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                'Thử tìm bằng tên nghệ sĩ hoặc album',
                style: GoogleFonts.outfit(color: c.textDisabled, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((_, i) {
        final song = results[i];
        return MusicListTile(
          song: song,
          isActive: player.currentSong?.id == song.id,
          onTap: () => onSongTap(results, song),
        );
      }, childCount: results.length),
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
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
        if (!context.mounted) return;
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
                      colors: [Colors.transparent, c.scrimMedium],
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
                    Icon(
                      s.icon,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 28,
                    ),
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
                            color: Colors.white.withValues(alpha: 0.7),
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
          ...recentlyAdded
              .take(5)
              .map(
                (song) => MusicListTile(
                  key: ValueKey('ra_${song.id}'),
                  song: song,
                  isActive: player.currentSong?.id == song.id,
                  onTap: () => onSongTap(recentlyAdded, song),
                ),
              ),
        ],
        if (neverPlayed.isNotEmpty) ...[
          _SectionHeader(title: 'Chưa từng nghe'),
          ...neverPlayed
              .take(5)
              .map(
                (song) => MusicListTile(
                  key: ValueKey('np_${song.id}'),
                  song: song,
                  isActive: player.currentSong?.id == song.id,
                  onTap: () => onSongTap(neverPlayed, song),
                ),
              ),
        ],
        // FIX 2: Empty state với nút quét — hướng user rõ ràng hơn
        if (recentlyAdded.isEmpty && neverPlayed.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 40, 40, 20),
              child: Column(
                children: [
                  Icon(
                    Icons.music_off_rounded,
                    color: c.textDisabled,
                    size: 48,
                  ),
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
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
      onTap:
          () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [c.primary, c.tertiary]),
        ),
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}
