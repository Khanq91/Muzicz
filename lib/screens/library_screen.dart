import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/mini_player.dart';
import '../widgets/music_list_tile.dart';
import 'artist_detail_screen.dart';
import 'now_playing_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final isScanning = music.status == LibraryStatus.scanning;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  if (!widget.isEmbedded)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  if (widget.isEmbedded) const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Thư viện',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  // UX 5: Show scanning indicator in header
                  if (isScanning)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  PopupMenuButton<SortType>(
                    color: AppColors.card,
                    icon: const Icon(Icons.sort_rounded,
                        color: AppColors.textSecondary),
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

            // UX 5: Thin linear progress when scanning
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isScanning ? 2 : 0,
              child: isScanning
                  ? LinearProgressIndicator(
                backgroundColor: AppColors.divider,
                color: AppColors.primary,
              )
                  : const SizedBox.shrink(),
            ),

            // ── Search ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (q) {
                  // FIX Bug 1: Use library-specific search
                  context.read<MusicProvider>().setLibrarySearchQuery(q);
                  setState(() {});
                },
                style: GoogleFonts.outfit(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tìm trong thư viện…',
                  hintStyle: GoogleFonts.outfit(
                      color: AppColors.textDisabled, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textTertiary, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      context
                          .read<MusicProvider>()
                          .setLibrarySearchQuery('');
                      setState(() {});
                    },
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.textTertiary, size: 18),
                  )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    const BorderSide(color: AppColors.primary, width: 1),
                  ),
                ),
              ),
            ),

            // ── TabBar with counts (UX 1) ────────────────
            _LibraryTabBar(tabCtrl: _tabCtrl, music: music),

            // ── Tab content ──────────────────────────────
            Expanded(
              child: _FadeTabBarView(
                controller: _tabCtrl,
                children: [
                  _SongsTab(sortType: _sortType),
                  const PlaylistsTab(),
                  _AlbumsTab(),
                  _ArtistsTab(),
                  _FoldersTab(),
                ],
              ),
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

// ── Songs Tab ─────────────────────────────────────────────

class _SongsTab extends StatelessWidget {
  const _SongsTab({required this.sortType});
  final SortType sortType;

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

    // FIX Bug 1: Use library-specific filtered songs
    final songs = _sorted(
      music.librarySearchQuery.isEmpty
          ? music.allSongs
          : music.libraryFilteredSongs,
    );

    if (songs.isEmpty) {
      return _EmptyState(
        icon: Icons.music_note_rounded,
        message: music.librarySearchQuery.isEmpty
            ? 'Chưa có nhạc nào.\nHãy quét thư viện của bạn.'
            : 'Không tìm thấy kết quả.',
        // UX 7: Better empty search feedback
        showSearchTip: music.librarySearchQuery.isNotEmpty,
        searchQuery: music.librarySearchQuery,
      );
    }

    // UX 2: Pull-to-refresh
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () => context.read<MusicProvider>().scanMusic(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: songs.length,
        itemBuilder: (_, i) {
          final song = songs[i];
          return MusicListTile(
            song: song,
            isActive: player.currentSong?.id == song.id,
            onTap: () {
              context
                  .read<PlayerProvider>()
                  .playSongs(songs, specificSong: song);
              context.read<MusicProvider>().onSongPlayed(song.id);
              Navigator.of(context).push(_playerRoute());
            },
          );
        },
      ),
    );
  }
}

// ── Albums Tab ────────────────────────────────────────────

class _AlbumsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final albums = music.albumMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (albums.isEmpty) {
      return const _EmptyState(
        icon: Icons.album_rounded,
        message: 'Không có album nào.',
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
            context.read<PlayerProvider>().playSongs(songs);
            Navigator.of(context).push(_playerRoute());
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.surfaceElevated,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: QueryArtworkWidget(
                      id: albumId,
                      type: ArtworkType.ALBUM,
                      artworkFit: BoxFit.cover,
                      artworkBorder: BorderRadius.zero,
                      keepOldArtwork: true,
                      // P3: Lower quality for grid thumbnails
                      artworkQuality: FilterQuality.low,
                      nullArtworkWidget: Container(
                        color: AppColors.surfaceElevated,
                        child: const Icon(
                          Icons.album_rounded,
                          color: AppColors.textDisabled,
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
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${songs.length} bài',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Artists Tab ───────────────────────────────────────────

class _ArtistsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final artists = music.artistMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (artists.isEmpty) {
      return const _EmptyState(
          icon: Icons.person_rounded, message: 'Không có nghệ sĩ nào.');
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: artists.length,
      itemBuilder: (_, i) {
        final entry = artists[i];
        final songs = entry.value;
        // FIX Bug 3: Use artistId for artist artwork
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
                // FIX Bug 3: Use ARTIST type instead of ALBUM
                type: ArtworkType.ARTIST,
                artworkFit: BoxFit.cover,
                artworkBorder: BorderRadius.zero,
                keepOldArtwork: true,
                nullArtworkWidget: Container(
                  color: AppColors.surfaceElevated,
                  child: Center(
                    child: Text(
                      entry.key.isNotEmpty
                          ? entry.key[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
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
                  color: AppColors.textPrimary)),
          subtitle: Text('${songs.length} bài hát',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppColors.textTertiary)),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppColors.textDisabled, size: 20),
          // UX 3: Navigate to ArtistDetailScreen instead of play all
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

// ── Folders Tab ───────────────────────────────────────────

class _FoldersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
      return const _EmptyState(
          icon: Icons.folder_rounded, message: 'Không có thư mục nào.');
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
              color: AppColors.primary.withOpacity(0.15),
            ),
            child: const Icon(Icons.folder_rounded,
                color: AppColors.primary, size: 24),
          ),
          title: Text(entry.key,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
          subtitle: Text('${entry.value.length} bài hát',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppColors.textTertiary)),
          onTap: () {
            context.read<PlayerProvider>().playSongs(entry.value);
            Navigator.of(context).push(_playerRoute());
          },
        );
      },
    );
  }
}

class _CountTab extends StatelessWidget {
  const _CountTab({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty state (UX 7: better search feedback) ─────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.showSearchTip = false,
    this.searchQuery = '',
  });
  final IconData icon;
  final String message;
  final bool showSearchTip;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textDisabled, size: 52),
          const SizedBox(height: 14),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  color: AppColors.textTertiary, fontSize: 14, height: 1.6)),
          // UX 7: Search tip
          if (showSearchTip) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    'Gợi ý tìm kiếm:',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Thử tìm bằng tên nghệ sĩ hoặc album',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.primary),
              label: Text(
                'Xóa tìm kiếm',
                style: GoogleFonts.outfit(
                    color: AppColors.primary, fontWeight: FontWeight.w600),
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