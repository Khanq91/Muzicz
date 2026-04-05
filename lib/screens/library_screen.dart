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
import 'now_playing_screen.dart';
import 'playlist_screen.dart';

enum SortType { az, recentlyAdded, duration }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.isEmbedded = false});
  final bool isEmbedded;   // ← THÊM

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
                  if (widget.isEmbedded)
                    const SizedBox(width: 16),
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
            // ── Search ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (q) {
                  context.read<MusicProvider>().setSearchQuery(q);
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
                            context.read<MusicProvider>().setSearchQuery('');
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
            // ── TabBar ──────────────────────────────────
            TabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(text: 'Bài hát'),
                Tab(text: 'Danh sách phát'),
                Tab(text: 'Album'),
                Tab(text: 'Nghệ sĩ'),
                Tab(text: 'Thư mục'),
              ],
            ),
            // ── Tab content — MUST be Expanded to avoid overflow ──
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _SongsTab(sortType: _sortType),
                  const PlaylistsTab(),
                  _AlbumsTab(),
                  _ArtistsTab(),
                  _FoldersTab(),
                   // PlaylistsTab(),
                ],
              ),
            ),
            // ── Mini player ─────────────────────────────
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
    final songs = _sorted(
      music.searchQuery.isEmpty ? music.allSongs : music.filteredSongs,
    );

    if (songs.isEmpty) {
      return _EmptyState(
        icon: Icons.music_note_rounded,
        message: music.searchQuery.isEmpty
            ? 'Chưa có nhạc nào.\nHãy quét thư viện của bạn.'
            : 'Không tìm thấy kết quả.',
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
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
        // Square art + text below
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
              // Square artwork
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
        final albumId = songs.first.albumId;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: SizedBox(
            width: 48,
            height: 48,
            child: ClipOval(
              child: QueryArtworkWidget(
                id: albumId,
                type: ArtworkType.ALBUM,
                artworkFit: BoxFit.cover,
                artworkBorder: BorderRadius.zero,
                keepOldArtwork: true,
                nullArtworkWidget: Container(
                  color: AppColors.surfaceElevated,
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.textDisabled, size: 24),
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
          onTap: () {
            context.read<PlayerProvider>().playSongs(songs);
            Navigator.of(context).push(_playerRoute());
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
            child:
                const Icon(Icons.folder_rounded, color: AppColors.primary, size: 24),
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

// ── Empty state ───────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

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
