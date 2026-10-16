import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import 'package:muziczz/core/app_strings.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import '../models/playlist_item.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/library/bulk_playlist_sheet.dart';
import '../widgets/library/library_empty_state.dart';
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
  final _libraryScreenKey = GlobalKey<LibraryScreenState>();

  late final _tabs = [
    LibraryScreen(key: _libraryScreenKey),
    _HomeTabBody(
      key: _homeTabKey,
      onShowAllPlaylists: () => _showLibraryTab(0),
      onShowAllSongs: (query) => _showLibraryTab(1, searchQuery: query),
    ),
    const ProfileScreen(embeddedInHome: true),
  ];

  void _showLibraryTab(int tabIndex, {String searchQuery = ''}) {
    _libraryScreenKey.currentState?.showTab(tabIndex, searchQuery: searchQuery);
    if (_currentIndex != 0) setState(() => _currentIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottomNavStyle = context.watch<ThemeProvider>().bottomNavStyle;
    return Scaffold(
      backgroundColor: c.background,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _currentIndex, children: _tabs),
          ),
        ],
      ),
      bottomNavigationBar: Consumer<PlayerProvider>(
        builder:
            (_, player, __) => AppBottomNavigation(
              currentIndex: _currentIndex,
              onTap: (index) {
                if (index != 1) _homeTabKey.currentState?.clearSelection();
                setState(() => _currentIndex = index);
              },
              style: bottomNavStyle,
              miniPlayer:
                  player.currentSong != null
                      ? const MiniPlayer(embeddedInDock: true)
                      : null,
            ),
      ),
    );
  }
}

class _HomeTabBody extends StatefulWidget {
  const _HomeTabBody({
    super.key,
    required this.onShowAllPlaylists,
    required this.onShowAllSongs,
  });

  final VoidCallback onShowAllPlaylists;
  final ValueChanged<String> onShowAllSongs;

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
    final displayedSongs = music.homeSongsSortedBy(switch (_sortType) {
      SortType.az => LibrarySongSort.title,
      SortType.recentlyAdded => LibrarySongSort.recentlyAdded,
      SortType.duration => LibrarySongSort.duration,
    });
    final visibleSongs = displayedSongs.take(10).toList(growable: false);
    // Snapshot mutable playlist fields so rename/add/remove notifications rebuild
    // the preview even when the provider retains the same list instance.
    context.select<MusicProvider, Object>(
      (provider) => provider.playlists
          .take(3)
          .map(
            (playlist) => (
              playlist.id,
              playlist.name,
              playlist.songCount,
              playlist.songs.firstOrNull?.albumId,
            ),
          )
          .toList(growable: false),
    );
    final homePlaylists = music.playlists.take(3).toList(growable: false);
    final isScanning = context.select<MusicProvider, bool>(
      (provider) => provider.status == LibraryStatus.scanning,
    );
    final hasScannedOnce = context.select<MusicProvider, bool>(
      (provider) => provider.hasScannedOnce,
    );
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
                                total: visibleSongs.length,
                                onToggleSelectAll:
                                    () => _toggleSelectAll(visibleSongs),
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
                  if (!_isSelecting && !_searchActive)
                    SliverToBoxAdapter(
                      child: _HomePlaylistSection(
                        playlists: homePlaylists,
                        onViewAll: widget.onShowAllPlaylists,
                      ),
                    ),
                  if (_searchActive && displayedSongs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: LibraryEmptyState(
                        icon: Icons.search_off_rounded,
                        message: AppStrings.noResultsDot,
                        showSearchTip: true,
                        searchQuery: music.homeSearchQuery,
                        onClearSearch: _clearSearch,
                      ),
                    )
                  else if (isInitialScan)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _InitialLibraryLoadingState(),
                    )
                  else if (displayedSongs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: LibraryEmptyState(
                        icon: Icons.music_note_rounded,
                        message: AppStrings.emptyLibrary,
                        onScanTap: _navigateToScan,
                      ),
                    )
                  else ...[
                    if (!_searchActive && !_isSelecting)
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: AppStrings.allSongsWithCount(allSongs.length),
                          actionLabel: AppStrings.viewAll,
                          onAction: () => widget.onShowAllSongs(''),
                          trailing: _HomeListActions(
                            isScanning: isScanning,
                            hasScannedOnce: hasScannedOnce,
                            sortType: _sortType,
                            onSortChanged:
                                (sort) => setState(() => _sortType = sort),
                          ),
                        ),
                      ),
                    if (_searchActive)
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: AppStrings.allSongsWithCount(
                            filteredSongs.length,
                          ),
                          actionLabel: AppStrings.viewAll,
                          onAction:
                              () => widget.onShowAllSongs(
                                _searchCtrl.text.trim(),
                              ),
                        ),
                      ),
                    SliverList.builder(
                      itemCount: visibleSongs.length,
                      itemBuilder: (_, index) {
                        final song = visibleSongs[index];
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
                      },
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: AppBottomNavigation.scrollBottomPadding(
                          context,
                          hasMiniPlayer: currentSongId != null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isSelecting)
            Padding(
              padding: EdgeInsets.only(
                bottom: AppBottomNavigation.scrollBottomPadding(
                  context,
                  hasMiniPlayer: currentSongId != null,
                ),
              ),
              child: SelectionActionBar(
                count: _selectedIds.length,
                onAddToPlaylist: () => _showBulkPlaylistSheet(music),
                onFavorite: () => _bulkFavorite(music),
                onHide: () => _bulkHide(music),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final favoriteSongs = context.select<MusicProvider, List<SongItem>>(
      (music) => music.favorites,
    );
    final allSongs = context.select<MusicProvider, List<SongItem>>(
      (music) => music.allSongs,
    );
    final c = context.appColors;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            _HomeQuickActionButton(
              label: AppStrings.favorites,
              icon: Icons.favorite_rounded,
              gradient: c.favoritesGradient,
              enabled: favoriteSongs.isNotEmpty,
              onTap:
                  favoriteSongs.isEmpty
                      ? null
                      : () => context.read<PlayerProvider>().playSongs(
                        favoriteSongs,
                      ),
            ),
            const SizedBox(width: 8),
            _HomeQuickActionButton(
              label: AppStrings.mix,
              icon: Icons.shuffle_rounded,
              gradient: c.randomMixGradient,
              enabled: allSongs.isNotEmpty,
              onTap:
                  allSongs.isEmpty
                      ? null
                      : () => context.read<PlayerProvider>().playSongsShuffled(
                        allSongs,
                      ),
            ),
          ],
        ),
      ),
    );
  }

  void _playSong(List<SongItem> songs, SongItem song) {
    context.read<PlayerProvider>().playSongs(songs, specificSong: song);
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

class _HomeQuickActionButton extends StatelessWidget {
  const _HomeQuickActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 58,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Ink(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: gradient,
                      boxShadow: [
                        BoxShadow(
                          color: c.primary.withValues(alpha: 0.14),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(icon, color: Colors.white, size: 21),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: c.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePlaylistSection extends StatelessWidget {
  const _HomePlaylistSection({
    required this.playlists,
    required this.onViewAll,
  });

  final List<PlaylistItem> playlists;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionHeader(
          title: AppStrings.playlist,
          actionLabel: AppStrings.viewAll,
          onAction: onViewAll,
        ),
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.noPlaylistsYet,
                style: GoogleFonts.outfit(
                  color: context.appColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          for (final playlist in playlists)
            _HomePlaylistTile(playlist: playlist),
      ],
    );
  }
}

class _HomePlaylistTile extends StatelessWidget {
  const _HomePlaylistTile({required this.playlist});

  final PlaylistItem playlist;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final firstSong = playlist.songs.isEmpty ? null : playlist.songs.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('home_playlist_${playlist.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
                ),
              ),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child:
                        firstSong == null
                            ? Container(
                              color: c.surfaceElevated,
                              child: Icon(
                                Icons.queue_music_rounded,
                                color: c.textTertiary,
                                size: 22,
                              ),
                            )
                            : QueryArtworkWidget(
                              id: firstSong.albumId,
                              type: ArtworkType.ALBUM,
                              artworkFit: BoxFit.cover,
                              artworkBorder: BorderRadius.zero,
                              keepOldArtwork: true,
                              nullArtworkWidget: Container(
                                color: c.surfaceElevated,
                                child: Icon(
                                  Icons.queue_music_rounded,
                                  color: c.textTertiary,
                                  size: 22,
                                ),
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppStrings.songCount(playlist.songCount),
                        style: GoogleFonts.outfit(
                          color: c.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: c.primary,
                minimumSize: const Size(44, 40),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(actionLabel!),
            ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _HomeListActions extends StatelessWidget {
  const _HomeListActions({
    required this.isScanning,
    required this.hasScannedOnce,
    required this.sortType,
    required this.onSortChanged,
  });

  final bool isScanning;
  final bool hasScannedOnce;
  final SortType sortType;
  final ValueChanged<SortType> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasScannedOnce) _ScanButton(isScanning: isScanning),
        PopupMenuButton<SortType>(
          tooltip: AppStrings.sort,
          color: c.card,
          icon: Icon(Icons.sort_rounded, color: c.textSecondary, size: 21),
          onSelected: onSortChanged,
          itemBuilder:
              (_) => [
                _sortItem(c, SortType.az, AppStrings.sortAZ, sortType),
                _sortItem(
                  c,
                  SortType.recentlyAdded,
                  AppStrings.sortNewest,
                  sortType,
                ),
                _sortItem(c, SortType.duration, AppStrings.duration, sortType),
              ],
        ),
      ],
    );
  }

  PopupMenuItem<SortType> _sortItem(
    AppColorsData colors,
    SortType type,
    String label,
    SortType selected,
  ) => PopupMenuItem(
    value: type,
    child: Text(
      label,
      style: GoogleFonts.outfit(
        color: selected == type ? colors.primary : colors.textPrimary,
        fontSize: 14,
      ),
    ),
  );
}
