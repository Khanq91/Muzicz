import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:provider/provider.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../widgets/library/albums_tab.dart';
import '../widgets/library/artists_tab.dart';
import '../widgets/library/bulk_playlist_sheet.dart';
import '../widgets/library/fade_tab_bar_view.dart';
import '../widgets/library/folders_tab.dart';
import '../widgets/library/library_search_bar.dart';
import '../widgets/library/library_tab_bar.dart';
import '../widgets/library/selection_action_bar.dart';
import '../widgets/library/selection_header.dart';
import '../widgets/library/songs_tab.dart';
import '../widgets/library/sort_type.dart';
import 'onboarding_screen.dart';
import 'playlist_screen.dart';
import 'package:muziczz/core/app_strings.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  SortType _sortType = SortType.az;

  // ── Selection state ────────────────────────────────────────────────────────
  bool _isSelecting = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    // No listener here: TabBar and FadeTabBarView follow the controller on
    // their own, so a tab change must not rebuild the whole screen.
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Selection methods ──────────────────────────────────────────────────────

  void _enterSelecting(SongItem song) {
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

  void _toggleSelect(SongItem song) {
    setState(() {
      if (_selectedIds.contains(song.id)) {
        _selectedIds.remove(song.id);
        if (_selectedIds.isEmpty) _isSelecting = false;
      } else {
        _selectedIds.add(song.id);
      }
    });
  }

  void _toggleSelectAll(MusicProvider music) {
    setState(() {
      final allSongs =
          music.librarySearchQuery.isEmpty
              ? music.allSongs
              : music.libraryFilteredSongs;
      final allIds = allSongs.map((s) => s.id).toSet();
      if (_selectedIds.containsAll(allIds) && allIds.isNotEmpty) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allIds);
      }
    });
  }

  List<SongItem> _getSelectedSongs(MusicProvider music) =>
      music.allSongs.where((s) => _selectedIds.contains(s.id)).toList();

  Future<void> _bulkFavorite(MusicProvider music) async {
    if (_selectedIds.isEmpty) return;
    await music.bulkFavoriteToggle(_selectedIds.toList());
    final allWereFav = music.allSongs
        .where((s) => _selectedIds.contains(s.id))
        .every((s) => music.isFavorite(s.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allWereFav
              ? AppStrings.addedToFavorites(_selectedIds.length)
              : AppStrings.removedFromFavorites(_selectedIds.length),
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
    final count = songs.length;
    final c = context.appColors;

    final confirm = await showDialog<bool>(
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

    if (confirm != true) return;
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
    final songs = _getSelectedSongs(music);
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => ChangeNotifierProvider.value(
            value: music,
            child: BulkPlaylistSheet(songs: songs),
          ),
    );
  }

  /// Empty-state "Xóa tìm kiếm": the field must be cleared too, or typing the
  /// same text again is a no-op for the debounced query.
  void _clearSearch() {
    _searchCtrl.clear();
    context.read<MusicProvider>().setLibrarySearchQuery('');
  }

  void _navigateToScan() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final isScanning = music.status == LibraryStatus.scanning;
    final c = context.appColors;

    // Tổng bài đang hiển thị (dùng cho "Chọn tất cả")
    final displayedTotal =
        music.librarySearchQuery.isEmpty
            ? music.allSongs.length
            : music.libraryFilteredSongs.length;

    return PopScope(
      // Back while selecting leaves selection mode instead of the screen.
      canPop: !_isSelecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelecting();
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ───────────────────────────────────────
              if (_isSelecting)
                SelectionHeader(
                  count: _selectedIds.length,
                  total: displayedTotal,
                  onToggleSelectAll: () => _toggleSelectAll(music),
                  onCancel: _exitSelecting,
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          AppStrings.library,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      if (isScanning)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.primary,
                            ),
                          ),
                        ),
                      PopupMenuButton<SortType>(
                        color: c.card,
                        icon: Icon(Icons.sort_rounded, color: c.textSecondary),
                        onSelected: (t) => setState(() => _sortType = t),
                        itemBuilder:
                            (_) => [
                              _menuItem(SortType.az, AppStrings.sortAZ),
                              _menuItem(
                                SortType.recentlyAdded,
                                AppStrings.sortNewest,
                              ),
                              _menuItem(SortType.duration, AppStrings.duration),
                            ],
                      ),
                    ],
                  ),
                ),

              // Scan progress bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: isScanning ? 2 : 0,
                child:
                    isScanning
                        ? LinearProgressIndicator(
                          backgroundColor: c.divider,
                          color: c.primary,
                        )
                        : const SizedBox.shrink(),
              ),

              // ── Search bar + scope indicator — ẩn khi selecting ──
              if (!_isSelecting) ...[
                LibrarySearchBar(controller: _searchCtrl),

                // ── TabBar ──────────────────────────────────────
                LibraryTabBar(tabCtrl: _tabCtrl, music: music),
              ],

              // ── Tab content ──────────────────────────────────
              // One SongsTab element in both modes: swapping the tab view for a
              // bare copy while selecting rebuilt the ListView and jumped to
              // the top. Selection starts from a long-press inside this tab,
              // so the view already sits on it, and the TabBar is hidden
              // above until selection ends.
              Expanded(
                child: FadeTabBarView(
                  controller: _tabCtrl,
                  children: [
                    SongsTab(
                      sortType: _sortType,
                      onScanTap: _navigateToScan,
                      isSelecting: _isSelecting,
                      selectedIds: _selectedIds,
                      onEnterSelect: _enterSelecting,
                      onToggleSelect: _toggleSelect,
                      onClearSearch: _clearSearch,
                    ),
                    const PlaylistsTab(),
                    AlbumsTab(onScanTap: _navigateToScan),
                    ArtistsTab(onScanTap: _navigateToScan),
                    FoldersTab(onScanTap: _navigateToScan),
                  ],
                ),
              ),

              // ── Action bar — chỉ hiện khi selecting ─────────
              if (_isSelecting)
                SelectionActionBar(
                  count: _selectedIds.length,
                  onAddToPlaylist: () => _showBulkPlaylistSheet(music),
                  onFavorite: () => _bulkFavorite(music),
                  onHide: () => _bulkHide(music),
                ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<SortType> _menuItem(SortType t, String label) {
    final c = context.appColors;
    return PopupMenuItem(
      value: t,
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: _sortType == t ? c.primary : c.textPrimary,
          fontSize: 14,
        ),
      ),
    );
  }
}
