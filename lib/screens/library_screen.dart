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
import '../widgets/mini_player.dart';
import '../widgets/music_list_tile.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'now_playing_screen.dart';
import 'onboarding_screen.dart';
import 'playlist_screen.dart';

enum SortType { az, recentlyAdded, duration }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.isEmbedded = false});
  final bool isEmbedded;

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
    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
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
      final allSongs = music.librarySearchQuery.isEmpty
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        allWereFav
            ? 'Đã thêm ${_selectedIds.length} bài vào yêu thích'
            : 'Đã bỏ ${_selectedIds.length} bài khỏi yêu thích',
        style: GoogleFonts.outfit(fontSize: 13),
      ),
      duration: const Duration(seconds: 2),
      backgroundColor: context.appColors.surfaceElevated,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _bulkHide(MusicProvider music) async {
    if (_selectedIds.isEmpty) return;
    final songs = _getSelectedSongs(music);
    final count = songs.length;
    final c = context.appColors;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Ẩn $count bài hát?',
            style: GoogleFonts.outfit(
                color: c.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          'Các bài hát này sẽ bị ẩn khỏi thư viện. File gốc không bị xóa.',
          style: GoogleFonts.outfit(
              color: c.textSecondary, fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy',
                style: GoogleFonts.outfit(color: c.textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Ẩn',
                style: GoogleFonts.outfit(
                    color: c.tertiary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await music.hideSongsFromLibrary(songs);
    _exitSelecting();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đã ẩn $count bài hát',
          style: GoogleFonts.outfit(fontSize: 13)),
      duration: const Duration(seconds: 2),
      backgroundColor: context.appColors.surfaceElevated,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
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
      builder: (_) => ChangeNotifierProvider.value(
        value: music,
        child: _BulkPlaylistSheet(songs: songs),
      ),
    );
  }

  void _navigateToScan() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final isScanning = music.status == LibraryStatus.scanning;
    final hasSearchText = _searchCtrl.text.isNotEmpty;
    final c = context.appColors;

    // Tổng bài đang hiển thị (dùng cho "Chọn tất cả")
    final displayedTotal = music.librarySearchQuery.isEmpty
        ? music.allSongs.length
        : music.libraryFilteredSongs.length;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────
            if (_isSelecting)
              _SelectionHeader(
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
                    if (!widget.isEmbedded)
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20, color: c.textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    if (widget.isEmbedded) const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Thư viện',
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
                      itemBuilder: (_) => [
                        _menuItem(SortType.az, 'A → Z'),
                        _menuItem(SortType.recentlyAdded, 'Mới thêm'),
                        _menuItem(SortType.duration, 'Thời lượng'),
                      ],
                    ),
                  ],
                ),
              ),

            // Scan progress bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isScanning ? 2 : 0,
              child: isScanning
                  ? LinearProgressIndicator(
                backgroundColor: c.divider,
                color: c.primary,
              )
                  : const SizedBox.shrink(),
            ),

            // ── Search bar + scope indicator — ẩn khi selecting ──
            if (!_isSelecting) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (q) {
                    context.read<MusicProvider>().setLibrarySearchQuery(q);
                    setState(() {});
                  },
                  style: GoogleFonts.outfit(
                      color: c.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Tìm trong thư viện…',
                    hintStyle: GoogleFonts.outfit(
                        color: c.textDisabled, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: c.textTertiary, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        context
                            .read<MusicProvider>()
                            .setLibrarySearchQuery('');
                        setState(() {});
                      },
                      child: Icon(Icons.close_rounded,
                          color: c.textTertiary, size: 18),
                    )
                        : null,
                    filled: true,
                    fillColor: c.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.primary, width: 1),
                    ),
                  ),
                ),
              ),

              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: hasSearchText ? 28 : 0,
                curve: Curves.easeOut,
                child: hasSearchText
                    ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(
                    children: [
                      Icon(Icons.storage_rounded,
                          size: 12, color: c.textDisabled),
                      const SizedBox(width: 5),
                      Text(
                        'Tìm trong thư viện cục bộ · ${context.watch<MusicProvider>().allSongs.length} bài',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: c.textDisabled,
                        ),
                      ),
                    ],
                  ),
                )
                    : const SizedBox.shrink(),
              ),

              // ── TabBar ──────────────────────────────────────
              _LibraryTabBar(tabCtrl: _tabCtrl, music: music),
            ],

            // ── Tab content ──────────────────────────────────
            Expanded(
              child: _isSelecting
              // Khi selecting: chỉ hiện danh sách bài hát (không có tab)
                  ? _SongsTab(
                sortType: _sortType,
                onScanTap: _navigateToScan,
                isSelecting: true,
                selectedIds: _selectedIds,
                onEnterSelect: _enterSelecting,
                onToggleSelect: _toggleSelect,
              )
                  : _FadeTabBarView(
                controller: _tabCtrl,
                children: [
                  _SongsTab(
                    sortType: _sortType,
                    onScanTap: _navigateToScan,
                    isSelecting: false,
                    selectedIds: const {},
                    onEnterSelect: _enterSelecting,
                    onToggleSelect: _toggleSelect,
                  ),
                  const PlaylistsTab(),
                  _AlbumsTab(onScanTap: _navigateToScan),
                  _ArtistsTab(onScanTap: _navigateToScan),
                  _FoldersTab(onScanTap: _navigateToScan),
                ],
              ),
            ),

            // ── Action bar — chỉ hiện khi selecting ─────────
            if (_isSelecting)
              _SelectionActionBar(
                count: _selectedIds.length,
                onAddToPlaylist: () => _showBulkPlaylistSheet(music),
                onFavorite: () => _bulkFavorite(music),
                onHide: () => _bulkHide(music),
              ),

            if (!widget.isEmbedded)
              Consumer<PlayerProvider>(
                builder: (_, player, __) => player.currentSong != null
                    ? const MiniPlayer()
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<SortType> _menuItem(SortType t, String label) {
    return PopupMenuItem(
      value: t,
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: _sortType == t ? AppColors.primary : AppColors.textPrimary,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ── Selection header ──────────────────────────────────────────────────────────

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({
    required this.count,
    required this.total,
    required this.onToggleSelectAll,
    required this.onCancel,
  });
  final int count;
  final int total;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final allSelected = total > 0 && count >= total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: c.textPrimary, size: 22),
            onPressed: onCancel,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              count == 0 ? 'Chọn bài hát' : '$count bài đã chọn',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onToggleSelectAll,
            child: Text(
              allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: c.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selection action bar ──────────────────────────────────────────────────────

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.count,
    required this.onAddToPlaylist,
    required this.onFavorite,
    required this.onHide,
  });
  final int count;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onFavorite;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final enabled = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionBarBtn(
            icon: Icons.playlist_add_rounded,
            label: 'Playlist',
            onTap: enabled ? onAddToPlaylist : null,
          ),
          _ActionBarBtn(
            icon: Icons.favorite_rounded,
            label: 'Yêu thích',
            onTap: enabled ? onFavorite : null,
          ),
          _ActionBarBtn(
            icon: Icons.visibility_off_rounded,
            label: 'Ẩn',
            onTap: enabled ? onHide : null,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _ActionBarBtn extends StatelessWidget {
  const _ActionBarBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final enabled = onTap != null;
    final color = !enabled
        ? c.textDisabled
        : isDestructive
        ? c.tertiary
        : c.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bulk playlist sheet ───────────────────────────────────────────────────────

class _BulkPlaylistSheet extends StatelessWidget {
  const _BulkPlaylistSheet({required this.songs});
  final List<SongItem> songs;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final c = context.appColors;
    final playlists = music.playlists;

    return Container(
      constraints:
      BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thêm vào danh sách phát',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        '${songs.length} bài hát',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: c.textTertiary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      color: c.textTertiary, size: 22),
                ),
              ],
            ),
          ),
          Divider(color: c.divider, height: 1),
          playlists.isEmpty
              ? Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.playlist_play_rounded,
                    color: c.textDisabled, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Chưa có danh sách phát nào.',
                  style: GoogleFonts.outfit(
                      color: c.textTertiary, fontSize: 14),
                ),
              ],
            ),
          )
              : Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: playlists.length,
              itemBuilder: (_, i) {
                final pl = playlists[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                          colors: [c.primary, c.secondary]),
                    ),
                    child: const Icon(Icons.playlist_play_rounded,
                        color: Colors.white, size: 22),
                  ),
                  title: Text(pl.name,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: c.textPrimary,
                      )),
                  subtitle: Text('${pl.songCount} bài hát',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: c.textTertiary)),
                  trailing:
                  Icon(Icons.add_rounded, color: c.primary),
                  onTap: () async {
                    await music.bulkAddToPlaylist(pl.id, songs);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        'Đã thêm ${songs.length} bài vào "${pl.name}"',
                        style: GoogleFonts.outfit(fontSize: 13),
                      ),
                      duration: const Duration(seconds: 2),
                      backgroundColor: c.surfaceElevated,
                      behavior: SnackBarBehavior.floating,
                      margin:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _LibraryTabBar extends StatelessWidget {
  const _LibraryTabBar({required this.tabCtrl, required this.music});
  final TabController tabCtrl;
  final MusicProvider music;

  int _getFolderCount() {
    final folderSet = <String>{};
    for (final s in music.allSongs) {
      final parts = s.data.split('/');
      parts.removeLast();
      folderSet.add(parts.isNotEmpty ? parts.last : 'Root');
    }
    return folderSet.length;
  }

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: tabCtrl,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        _CountTab(label: 'Bài hát', count: music.allSongs.length),
        _CountTab(label: 'DS Phát', count: music.playlists.length),
        _CountTab(label: 'Album', count: music.albumMap.length),
        _CountTab(label: 'Nghệ sĩ', count: music.artistMap.length),
        _CountTab(label: 'Thư mục', count: _getFolderCount()),
      ],
    );
  }
}

// ── Fade tab switcher ─────────────────────────────────────────────────────────

class _FadeTabBarView extends StatefulWidget {
  const _FadeTabBarView({
    required this.controller,
    required this.children,
  });
  final TabController controller;
  final List<Widget> children;

  @override
  State<_FadeTabBarView> createState() => _FadeTabBarViewState();
}

class _FadeTabBarViewState extends State<_FadeTabBarView> {
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    _idx = widget.controller.index;
    widget.controller.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (!widget.controller.indexIsChanging) return;
    setState(() => _idx = widget.controller.index);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: KeyedSubtree(
        key: ValueKey(_idx),
        child: widget.children[_idx],
      ),
    );
  }
}

// ── Songs Tab ─────────────────────────────────────────────────────────────────

class _SongsTab extends StatelessWidget {
  const _SongsTab({
    required this.sortType,
    required this.onScanTap,
    this.isSelecting = false,
    this.selectedIds = const {},
    this.onEnterSelect,
    this.onToggleSelect,
  });
  final SortType sortType;
  final VoidCallback onScanTap;
  final bool isSelecting;
  final Set<int> selectedIds;
  final void Function(SongItem)? onEnterSelect;
  final void Function(SongItem)? onToggleSelect;

  List<SongItem> _sorted(List<SongItem> songs) {
    final list = [...songs];
    switch (sortType) {
      case SortType.az:
        list.sort((a, b) => a.title.compareTo(b.title));
      case SortType.recentlyAdded:
        list.sort((a, b) => (b.dateAdded ?? DateTime(0))
            .compareTo(a.dateAdded ?? DateTime(0)));
      case SortType.duration:
        list.sort((a, b) => b.duration.compareTo(a.duration));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<PlayerProvider>();
    final c = context.appColors;
    final songs = _sorted(
      music.librarySearchQuery.isEmpty
          ? music.allSongs
          : music.libraryFilteredSongs,
    );

    if (songs.isEmpty) {
      return _EmptyState(
        icon: Icons.music_note_rounded,
        message: music.librarySearchQuery.isEmpty
            ? 'Chưa có nhạc nào trong thư viện.'
            : 'Không tìm thấy kết quả.',
        showSearchTip: music.librarySearchQuery.isNotEmpty,
        searchQuery: music.librarySearchQuery,
        onScanTap: music.librarySearchQuery.isEmpty ? onScanTap : null,
      );
    }

    return RefreshIndicator(
      color: c.primary,
      backgroundColor: c.card,
      onRefresh: () => context.read<MusicProvider>().scanMusic(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        // Extra padding khi selecting để action bar không che list
        padding: EdgeInsets.only(bottom: isSelecting ? 8 : 12),
        itemCount: songs.length,
        itemBuilder: (_, i) {
          final song = songs[i];
          return MusicListTile(
            song: song,
            isActive: !isSelecting && player.currentSong?.id == song.id,
            isSelecting: isSelecting,
            isSelected: selectedIds.contains(song.id),
            onTap: isSelecting
                ? () => onToggleSelect?.call(song)
                : () {
              context
                  .read<PlayerProvider>()
                  .playSongs(songs, specificSong: song);
              context.read<MusicProvider>().onSongPlayed(song.id);
              Navigator.of(context).push(_playerRoute());
            },
            onLongPress: isSelecting
                ? null
                : () {
              HapticFeedback.mediumImpact();
              onEnterSelect?.call(song);
            },
          );
        },
      ),
    );
  }
}

// ── Albums Tab ────────────────────────────────────────────────────────────────

class _AlbumsTab extends StatelessWidget {
  const _AlbumsTab({required this.onScanTap});
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final albums = music.albumMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final c = context.appColors;

    if (albums.isEmpty) {
      return _EmptyState(
        icon: Icons.album_rounded,
        message: 'Không có album nào.',
        onScanTap: onScanTap,
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (_, i) {
        final entry = albums[i];
        final songs = entry.value;
        final albumId = songs.first.albumId;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AlbumDetailScreen(
                  albumName: entry.key,
                  songs: songs,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: c.surfaceElevated,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: QueryArtworkWidget(
                      id: albumId,
                      type: ArtworkType.ALBUM,
                      artworkFit: BoxFit.cover,
                      artworkBorder: BorderRadius.zero,
                      keepOldArtwork: true,
                      artworkQuality: FilterQuality.low,
                      nullArtworkWidget: Container(
                        color: c.surfaceElevated,
                        child: Icon(
                          Icons.album_rounded,
                          color: c.textDisabled,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              Text(
                '${songs.length} bài',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: c.textTertiary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Artists Tab ───────────────────────────────────────────────────────────────

class _ArtistsTab extends StatelessWidget {
  const _ArtistsTab({required this.onScanTap});
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final artists = music.artistMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final c = context.appColors;
    if (artists.isEmpty) {
      return _EmptyState(
        icon: Icons.person_rounded,
        message: 'Không có nghệ sĩ nào.',
        onScanTap: onScanTap,
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: artists.length,
      itemBuilder: (_, i) {
        final entry = artists[i];
        final songs = entry.value;
        final artistId = songs.first.artistId;

        return ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: SizedBox(
            width: 48,
            height: 48,
            child: ClipOval(
              child: QueryArtworkWidget(
                id: artistId,
                type: ArtworkType.ARTIST,
                artworkFit: BoxFit.cover,
                artworkBorder: BorderRadius.zero,
                keepOldArtwork: true,
                nullArtworkWidget: Container(
                  color: c.surfaceElevated,
                  child: Center(
                    child: Text(
                      entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          title: Text(entry.key,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary)),
          subtitle: Text('${songs.length} bài hát',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: c.textTertiary)),
          trailing: Icon(Icons.chevron_right_rounded,
              color: c.textDisabled, size: 20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArtistDetailScreen(
                  artistName: entry.key,
                  songs: songs,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Folders Tab ───────────────────────────────────────────────────────────────

class _FoldersTab extends StatelessWidget {
  const _FoldersTab({required this.onScanTap});
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final music = context.watch<MusicProvider>();
    final folderMap = <String, List<SongItem>>{};
    for (final s in music.allSongs) {
      final parts = s.data.split('/');
      parts.removeLast();
      final folderName = parts.isNotEmpty ? parts.last : 'Root';
      folderMap.putIfAbsent(folderName, () => []).add(s);
    }

    final folders = folderMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (folders.isEmpty) {
      return _EmptyState(
        icon: Icons.folder_rounded,
        message: 'Không có thư mục nào.',
        onScanTap: onScanTap,
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: folders.length,
      itemBuilder: (_, i) {
        final entry = folders[i];
        return ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: c.primary.withOpacity(0.15),
            ),
            child: Icon(Icons.folder_rounded, color: c.primary, size: 24),
          ),
          title: Text(entry.key,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary)),
          subtitle: Text('${entry.value.length} bài hát',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: c.textTertiary)),
          onTap: () {
            context.read<PlayerProvider>().playSongs(entry.value);
            Navigator.of(context).push(_playerRoute());
          },
        );
      },
    );
  }
}

// ── Count tab ─────────────────────────────────────────────────────────────────

class _CountTab extends StatelessWidget {
  const _CountTab({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: c.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.showSearchTip = false,
    this.searchQuery = '',
    this.onScanTap,
  });
  final IconData icon;
  final String message;
  final bool showSearchTip;
  final String searchQuery;
  final VoidCallback? onScanTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c.textDisabled, size: 52),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                color: c.textTertiary, fontSize: 14, height: 1.6),
          ),
          if (onScanTap != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onScanTap,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(
                'Quét ngay',
                style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          if (showSearchTip) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Column(
                children: [
                  Text(
                    'Gợi ý tìm kiếm:',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: c.textTertiary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Thử tìm bằng tên nghệ sĩ hoặc album',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: c.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                context.read<MusicProvider>().setLibrarySearchQuery('');
              },
              icon: Icon(Icons.close_rounded, size: 16, color: c.primary),
              label: Text(
                'Xóa tìm kiếm',
                style: GoogleFonts.outfit(
                    color: c.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

PageRouteBuilder _playerRoute() => PageRouteBuilder(
  pageBuilder: (_, anim, __) => const NowPlayingScreen(),
  transitionDuration: const Duration(milliseconds: 400),
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: child,
  ),
);