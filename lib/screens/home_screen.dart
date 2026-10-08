import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:muziczz/core/app_strings.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/library/bulk_playlist_sheet.dart';
import '../widgets/library/library_empty_state.dart';
import '../widgets/library/player_route.dart';
import '../widgets/library/selection_action_bar.dart';
import '../widgets/library/selection_header.dart';
import '../widgets/library/sort_type.dart';
import '../widgets/mini_player.dart';
import '../widgets/music_list_tile.dart';
import 'library_screen.dart';
import 'onboarding_screen.dart';
import 'playlist_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1;
  final _homeTabKey = GlobalKey<_HomeTabBodyState>();

  late final _tabs = [
    const LibraryScreen(),
    _HomeTabBody(key: _homeTabKey),
    const ProfileScreen(embeddedInHome: true),
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
        onTap: (index) {
          if (index != 1) _homeTabKey.currentState?.clearSelection();
          setState(() => _currentIndex = index);
        },
        style: bottomNavStyle,
      ),
    );
  }
}

class _HomeTabBody extends StatefulWidget {
  const _HomeTabBody({super.key});

  @override
  State<_HomeTabBody> createState() => _HomeTabBodyState();
}

class _HomeTabBodyState extends State<_HomeTabBody> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final Set<int> _selectedIds = {};
  SortType _sortType = SortType.az;
  bool _searchActive = false;
  bool _isSelecting = false;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.greetingMorning;
    if (hour < 18) return AppStrings.greetingAfternoon;
    return AppStrings.greetingEvening;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _enterSelecting(SongItem song) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelecting = true;
      _selectedIds.add(song.id);
    });
  }

  void _exitSelecting() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  void clearSelection() {
    if (_isSelecting) _exitSelecting();
  }

  void _toggleSelect(SongItem song) {
    setState(() {
      if (_selectedIds.remove(song.id)) {
        if (_selectedIds.isEmpty) _isSelecting = false;
      } else {
        _selectedIds.add(song.id);
      }
    });
  }

  void _toggleSelectAll(List<SongItem> visibleSongs) {
    final visibleIds = visibleSongs.map((song) => song.id).toSet();
    setState(() {
      if (visibleIds.isNotEmpty && _selectedIds.containsAll(visibleIds)) {
        _selectedIds.removeAll(visibleIds);
        if (_selectedIds.isEmpty) _isSelecting = false;
      } else {
        _selectedIds.addAll(visibleIds);
        _isSelecting = true;
      }
    });
  }

  List<SongItem> _getSelectedSongs(MusicProvider music) =>
      music.allSongs.where((song) => _selectedIds.contains(song.id)).toList();

  Future<void> _bulkFavorite(MusicProvider music) async {
    if (_selectedIds.isEmpty) return;
    final selected = _getSelectedSongs(music);
    await music.bulkFavoriteToggle(_selectedIds.toList());
    final allAreFavorites =
        selected.isNotEmpty &&
        selected.every((song) => music.isFavorite(song.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allAreFavorites
              ? AppStrings.addedToFavorites(selected.length)
              : AppStrings.removedFromFavorites(selected.length),
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

  Future<void> _bulkHide(MusicProvider music) async {
    if (_selectedIds.isEmpty) return;
    final songs = _getSelectedSongs(music);
    if (songs.isEmpty) return;
    final count = songs.length;
    final c = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              AppStrings.hideSongsTitle(count),
              style: GoogleFonts.outfit(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              AppStrings.hideSongsBody,
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
                  AppStrings.hide,
                  style: GoogleFonts.outfit(
                    color: c.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await music.hideSongsFromLibrary(songs);
    if (!mounted) return;
    _exitSelecting();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.hiddenSongsDone(count),
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

  void _showBulkPlaylistSheet(MusicProvider music) {
    if (_selectedIds.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => ChangeNotifierProvider.value(
            value: music,
            child: BulkPlaylistSheet(songs: _getSelectedSongs(music)),
          ),
    );
  }

  void _clearSearch() {
    _searchCtrl.clear();
    context.read<MusicProvider>().setHomeSearchQuery('');
    setState(() => _searchActive = false);
  }

  void _navigateToScan() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final (status, allSongs, filteredSongs) = context
        .select<MusicProvider, (LibraryStatus, List<SongItem>, List<SongItem>)>(
          (music) => (music.status, music.allSongs, music.filteredSongs),
        );
    final music = context.read<MusicProvider>();
    final currentSongId = context.select<PlayerProvider, int?>(
      (player) => player.currentSong?.id,
    );
    final usesGlassNavigation = context.select<ThemeProvider, bool>(
      (theme) => theme.bottomNavStyle.usesLiquidGlass,
    );
    final displayedSongs = music.homeSongsSortedBy(switch (_sortType) {
      SortType.az => LibrarySongSort.title,
      SortType.recentlyAdded => LibrarySongSort.recentlyAdded,
      SortType.duration => LibrarySongSort.duration,
    });
    final isInitialScan = status == LibraryStatus.scanning && allSongs.isEmpty;
    final route = ModalRoute.of(context);

    return PopScope(
      canPop: !_isSelecting || !(route?.isCurrent ?? true),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelecting) _exitSelecting();
      },
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: context.appColors.primary,
              backgroundColor: context.appColors.card,
              onRefresh: () => context.read<MusicProvider>().scanMusic(),
              child: CustomScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child:
                        _isSelecting
                            ? SafeArea(
                              bottom: false,
                              child: SelectionHeader(
                                count: _selectedIds.length,
                                total: filteredSongs.length,
                                onToggleSelectAll:
                                    () => _toggleSelectAll(displayedSongs),
                                onCancel: _exitSelecting,
                              ),
                            )
                            : _buildHeader(),
                  ),
                  if (!_isSelecting)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SearchBarDelegate(
                        searchCtrl: _searchCtrl,
                        onChanged: (query) {
                          context.read<MusicProvider>().setHomeSearchQuery(
                            query,
                          );
                          setState(
                            () => _searchActive = query.trim().isNotEmpty,
                          );
                        },
                        onClear: _clearSearch,
                      ),
                    ),
                  if (isInitialScan)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _InitialLibraryLoadingState(),
                    )
                  else if (displayedSongs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: LibraryEmptyState(
                        icon:
                            _searchActive
                                ? Icons.search_off_rounded
                                : Icons.music_note_rounded,
                        message:
                            _searchActive
                                ? AppStrings.noResultsDot
                                : AppStrings.emptyLibrary,
                        showSearchTip: _searchActive,
                        searchQuery: music.homeSearchQuery,
                        onScanTap: _searchActive ? null : _navigateToScan,
                        onClearSearch: _searchActive ? _clearSearch : null,
                      ),
                    )
                  else ...[
                    if (!_searchActive && !_isSelecting)
                      SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: _QuickAccessSection(
                            allSongsCount: allSongs.length,
                            onFavoritesTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => const PlaylistDetailScreen(
                                        playlistId:
                                            MusicProvider.favoritesPlaylistId,
                                      ),
                                ),
                              );
                            },
                            onRandomTap: () {
                              if (allSongs.isEmpty) return;
                              context.read<PlayerProvider>().playSongsShuffled(
                                allSongs,
                              );
                              Navigator.of(context).push(playerRoute());
                            },
                          ),
                        ),
                      ),
                    if (!_searchActive && !_isSelecting)
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: AppStrings.allSongsWithCount(allSongs.length),
                        ),
                      ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((_, index) {
                        final song = displayedSongs[index];
                        return MusicListTile(
                          key: ValueKey('home_song_${song.id}'),
                          song: song,
                          isActive: !_isSelecting && currentSongId == song.id,
                          isSelecting: _isSelecting,
                          isSelected: _selectedIds.contains(song.id),
                          onTap:
                              _isSelecting
                                  ? () => _toggleSelect(song)
                                  : () => _playSong(displayedSongs, song),
                          onLongPress:
                              _isSelecting ? null : () => _enterSelecting(song),
                        );
                      }, childCount: displayedSongs.length),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ],
              ),
            ),
          ),
          if (_isSelecting)
            SelectionActionBar(
              count: _selectedIds.length,
              onAddToPlaylist: () => _showBulkPlaylistSheet(music),
              onFavorite: () => _bulkFavorite(music),
              onHide: () => _bulkHide(music),
            ),
          if (_isSelecting && currentSongId != null && usesGlassNavigation)
            const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isScanning = context.select<MusicProvider, bool>(
      (music) => music.status == LibraryStatus.scanning,
    );
    final hasScannedOnce = context.select<MusicProvider, bool>(
      (music) => music.hasScannedOnce,
    );
    final c = context.appColors;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
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
                    AppStrings.appName,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (hasScannedOnce) _ScanButton(isScanning: isScanning),
            PopupMenuButton<SortType>(
              color: c.card,
              icon: Icon(Icons.sort_rounded, color: c.textSecondary),
              onSelected: (type) => setState(() => _sortType = type),
              itemBuilder:
                  (_) => [
                    _menuItem(SortType.az, AppStrings.sortAZ),
                    _menuItem(SortType.recentlyAdded, AppStrings.sortNewest),
                    _menuItem(SortType.duration, AppStrings.duration),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  void _playSong(List<SongItem> songs, SongItem song) {
    context.read<PlayerProvider>().playSongs(songs, specificSong: song);
    Navigator.of(context).push(playerRoute());
  }

  PopupMenuItem<SortType> _menuItem(SortType type, String label) {
    final c = context.appColors;
    return PopupMenuItem(
      value: type,
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: _sortType == type ? c.primary : c.textPrimary,
          fontSize: 14,
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
      label: AppStrings.libraryLoading,
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
                AppStrings.libraryLoadingEllipsis,
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
                tooltip: AppStrings.rescanMusic,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: c.textTertiary,
                  size: 22,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  );
                },
              ),
    );
  }
}

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
          hintText: AppStrings.searchHint,
          hintStyle: GoogleFonts.outfit(color: c.textDisabled, fontSize: 15),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: c.textTertiary,
            size: 22,
          ),
          suffixIcon:
              searchCtrl.text.isNotEmpty
                  ? Semantics(
                    button: true,
                    label: AppStrings.clearSearch,
                    child: GestureDetector(
                      onTap: onClear,
                      child: Icon(
                        Icons.close_rounded,
                        color: c.textTertiary,
                        size: 20,
                      ),
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

class _QuickAccessSection extends StatelessWidget {
  const _QuickAccessSection({
    required this.allSongsCount,
    required this.onFavoritesTap,
    required this.onRandomTap,
  });

  final int allSongsCount;
  final VoidCallback onFavoritesTap;
  final VoidCallback onRandomTap;

  @override
  Widget build(BuildContext context) {
    final favoriteCount = context.select<MusicProvider, int>(
      (music) => music.favorites.length,
    );
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: AppStrings.quickAccess),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  title: AppStrings.favorites,
                  subtitle: AppStrings.songCountShort(favoriteCount),
                  icon: Icons.favorite_rounded,
                  gradient: c.favoritesGradient,
                  onTap: onFavoritesTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  title: AppStrings.random,
                  subtitle: AppStrings.songCountShort(allSongsCount),
                  icon: Icons.shuffle_rounded,
                  gradient: c.randomMixGradient,
                  onTap: allSongsCount == 0 ? null : onRandomTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            height: 112,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: gradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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
