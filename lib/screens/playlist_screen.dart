import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/utils/duration_format.dart';
import 'package:muziczz/utils/vietnamese_normalize.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/playlist_item.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/library/library_empty_state.dart';
import '../widgets/music_list_tile.dart';
import '../widgets/library/library_chrome.dart';
import 'package:muziczz/core/app_strings.dart';

/// Tab content: list of all playlists
class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key, required this.onClearSearch});

  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final hasMiniPlayer = context.select<PlayerProvider, bool>(
      (player) => player.currentSong != null,
    );
    final query = vnNormalize(music.librarySearchQuery.trim());
    final playlists = [music.favoritesPlaylist, ...music.playlists]
        .where(
          (playlist) =>
              query.isEmpty || vnNormalize(playlist.name).contains(query),
        )
        .toList(growable: false);
    return Stack(
      children: [
        if (playlists.isEmpty)
          LibraryEmptyState(
            icon: Icons.search_off_rounded,
            message: AppStrings.noResultsDot,
            showSearchTip: true,
            searchQuery: music.librarySearchQuery,
            onClearSearch: onClearSearch,
          )
        else
          ListView.separated(
            key: const PageStorageKey<String>('library_playlists'),
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: AppBottomNavigation.scrollBottomPadding(
                context,
                hasMiniPlayer: hasMiniPlayer,
              ),
            ),
            itemCount: playlists.length,
            separatorBuilder: (_, _) => const SizedBox(height: 2),
            itemBuilder: (context, i) {
              final pl = playlists[i];
              final isSystemPlaylist =
                  pl.id == MusicProvider.favoritesPlaylistId;
              return _PlaylistTile(
                key: ValueKey('library_playlist_${pl.id}'),
                playlist: pl,
                isSystemPlaylist: isSystemPlaylist,
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
                      ),
                    ),
                onDelete:
                    isSystemPlaylist
                        ? null
                        : () => _confirmDelete(context, music, pl),
              );
            },
          ),
        // FAB: create new playlist
        Positioned(
          bottom: AppBottomNavigation.floatingActionBottom(
            context,
            hasMiniPlayer: hasMiniPlayer,
          ),
          right: 16,
          child: _CreatePlaylistFab(),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MusicProvider music,
    PlaylistItem pl,
  ) async {
    final c = context.appColors;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              AppStrings.deletePlaylistTitle(pl.name),
              style: GoogleFonts.outfit(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              AppStrings.deletePlaylistBody,
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
                  AppStrings.delete,
                  style: GoogleFonts.outfit(
                    color: c.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
    if (ok != true) return;
    await music.deletePlaylist(pl.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.deletedPlaylist(pl.name),
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
}

// ── Playlist tile ─────────────────────────────────────────

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    super.key,
    required this.playlist,
    required this.isSystemPlaylist,
    required this.onTap,
    required this.onDelete,
  });
  final PlaylistItem playlist;
  final bool isSystemPlaylist;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: _PlaylistCover(playlist: playlist, size: 52),
      title: Text(
        playlist.name,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
      ),
      subtitle: Text(
        AppStrings.playlistMeta(
          playlist.songCount,
          playlist.totalDuration.compact,
        ),
        style: GoogleFonts.outfit(fontSize: 12, color: c.textTertiary),
      ),
      trailing:
          isSystemPlaylist
              ? Icon(Icons.favorite_rounded, color: c.tertiary, size: 20)
              : PopupMenuButton<String>(
                color: c.card,
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: c.textTertiary,
                  size: 20,
                ),
                onSelected: (val) {
                  if (val == 'delete') onDelete?.call();
                },
                itemBuilder:
                    (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: c.tertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppStrings.delete,
                              style: GoogleFonts.outfit(
                                color: c.tertiary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
      onTap: onTap,
    );
  }
}

// ── Playlist cover ────────────────────────────────────────

class _PlaylistCover extends StatelessWidget {
  const _PlaylistCover({required this.playlist, this.size = 52});
  final PlaylistItem playlist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (playlist.id == MusicProvider.favoritesPlaylistId) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: c.favoritesGradient,
        ),
        child: Icon(Icons.favorite_rounded, color: c.onPlayer, size: size * .5),
      );
    }
    // Grid of up to 4 album arts
    final songs = playlist.songs.take(4).toList();
    if (songs.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(colors: [c.primary, c.secondary]),
        ),
        child: Icon(
          Icons.playlist_play_rounded,
          color: c.onPlayer,
          size: size * 0.5,
        ),
      );
    }
    if (songs.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: QueryArtworkWidget(
          id: songs[0].albumId,
          type: ArtworkType.ALBUM,
          artworkFit: BoxFit.cover,
          artworkBorder: BorderRadius.zero,
          keepOldArtwork: true,
          artworkWidth: size,
          artworkHeight: size,
          nullArtworkWidget: _defaultCover(context, size),
        ),
      );
    }
    // 2x2 grid
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(4, (i) {
            if (i >= songs.length) {
              return Container(color: c.surfaceElevated);
            }
            return QueryArtworkWidget(
              id: songs[i].albumId,
              type: ArtworkType.ALBUM,
              artworkFit: BoxFit.cover,
              artworkBorder: BorderRadius.zero,
              keepOldArtwork: true,
              nullArtworkWidget: Container(color: c.surfaceElevated),
            );
          }),
        ),
      ),
    );
  }

  Widget _defaultCover(BuildContext context, double size) {
    final c = context.appColors;
    return Container(
      color: c.surfaceElevated,
      child: Icon(
        Icons.music_note_rounded,
        color: c.textDisabled,
        size: size * 0.4,
      ),
    );
  }
}

// ── FAB create playlist ───────────────────────────────────

class _CreatePlaylistFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Semantics(
      button: true,
      label: AppStrings.createPlaylist,
      child: GestureDetector(
        onTap: () => _showCreateDialog(context),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: c.primaryGradient,
            boxShadow: [
              BoxShadow(color: c.primary, blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Icon(Icons.add_rounded, color: c.onPlayer, size: 28),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final c = context.appColors;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              AppStrings.createPlaylist,
              style: GoogleFonts.outfit(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.outfit(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: AppStrings.playlistNameHint,
                hintStyle: GoogleFonts.outfit(color: c.textDisabled),
                filled: true,
                fillColor: c.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.primary, width: 1),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppStrings.cancel,
                  style: GoogleFonts.outfit(color: c.textTertiary),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) return;
                  await context.read<MusicProvider>().createPlaylist(name);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(
                  AppStrings.create,
                  style: GoogleFonts.outfit(
                    color: c.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    ).whenComplete(ctrl.dispose);
  }
}

// ── Playlist detail screen ────────────────────────────────

class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});
  final String playlistId;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late final TextEditingController _searchCtrl;
  String _searchQuery = '';
  final _songSearchText = Expando<String>();

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final playlistId = widget.playlistId;
    final isSystemPlaylist = playlistId == MusicProvider.favoritesPlaylistId;
    // Player state is only rendered per tile (isActive); read it here so a
    // play/pause, track change or sleep-timer tick does not rebuild the
    // SliverAppBar, header image, buttons and the whole list.
    final player = context.read<PlayerProvider>();
    final playlist =
        isSystemPlaylist
            ? music.favoritesPlaylist
            : music.playlists.firstWhere((p) => p.id == playlistId);
    final normalizedQuery = vnNormalize(_searchQuery.trim());
    final visibleSongs =
        normalizedQuery.isEmpty
            ? playlist.songs
            : playlist.songs
                .where((song) {
                  final text =
                      _songSearchText[song] ??= vnNormalize(
                        '${song.title}\u0000${song.artist}\u0000${song.album}',
                      );
                  return text.contains(normalizedQuery);
                })
                .toList(growable: false);
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: c.background,
            leading: IconButton(
              tooltip: AppStrings.back,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: c.textPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (!isSystemPlaylist)
                IconButton(
                  tooltip: AppStrings.rename,
                  icon: Icon(
                    Icons.edit_rounded,
                    color: c.textPrimary,
                    size: 22,
                  ),
                  onPressed: () => _showEditDialog(context, music, playlist),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _PlaylistHeader(playlist: playlist),
            ),
          ),
          // Play all button
          if (playlist.songs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _PlayButton(
                        label: AppStrings.playAll,
                        icon: Icons.play_arrow_rounded,
                        onTap: () {
                          player.playSongs(
                            playlist.songs,
                            sourceName: playlist.name,
                          );
                        },
                        primary: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PlayButton(
                        label: AppStrings.shuffle,
                        icon: Icons.shuffle_rounded,
                        onTap: () {
                          player.playSongsShuffled(
                            playlist.songs,
                            sourceName: playlist.name,
                          );
                        },
                        primary: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _PlayButton(
                        label: AppStrings.shuffleLoop,
                        icon: Icons.all_inclusive_rounded,
                        onTap: () {
                          player.enableShuffleLoop(playlist.songs);
                        },
                        primary: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Nút info
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder:
                              (_) => AlertDialog(
                                backgroundColor: c.card,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Row(
                                  children: [
                                    Icon(
                                      Icons.all_inclusive_rounded,
                                      color: c.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppStrings.shuffleLoop,
                                      style: GoogleFonts.outfit(
                                        color: c.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                content: Text(
                                  AppStrings.shuffleLoopDescription,
                                  style: GoogleFonts.outfit(
                                    color: c.textSecondary,
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      AppStrings.ok,
                                      style: GoogleFonts.outfit(
                                        color: c.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        );
                      },
                      child: Semantics(
                        button: true,
                        label: AppStrings.shuffleLoopInfo,
                        child: Container(
                          width: 40,
                          height: 46,
                          decoration: BoxDecoration(
                            color: c.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border, width: 0.5),
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: c.textTertiary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPersistentHeader(
              pinned: true,
              delegate: _PlaylistSearchHeader(
                controller: _searchCtrl,
                query: _searchQuery,
                onChanged: (query) => setState(() => _searchQuery = query),
                onClear: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            ),
          ],
          // Song list with reorder
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.songCount(visibleSongs.length),
                    style: GoogleFonts.outfit(
                      color: c.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                  if (!isSystemPlaylist)
                    TextButton.icon(
                      onPressed:
                          () => _showAddSongsSheet(context, music, playlist),
                      style: TextButton.styleFrom(
                        foregroundColor: c.primary,
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(AppStrings.addSongs),
                    ),
                ],
              ),
            ),
          ),
          if (playlist.songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      color: c.textDisabled,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isSystemPlaylist
                          ? AppStrings.emptyFavoritesHint
                          : AppStrings.emptyPlaylistHint,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: c.textTertiary,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (visibleSongs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  AppStrings.noResultsDot,
                  style: GoogleFonts.outfit(
                    color: c.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: visibleSongs.length,
              itemBuilder: (_, i) {
                final song = visibleSongs[i];
                return Selector<PlayerProvider, int?>(
                  key: ValueKey('playlist_song_${song.id}'),
                  selector: (_, p) => p.currentSong?.id,
                  builder:
                      (_, activeId, __) => Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        child: MusicListTile(
                          libraryStyle: true,
                          song: song,
                          isActive: activeId == song.id,
                          onTap: () {
                            player.playSongs(
                              playlist.songs,
                              specificSong: song,
                              sourceName: playlist.name,
                            );
                          },
                          // IconButton: 48dp target + tooltip/semantics label.
                          trailing:
                              isSystemPlaylist
                                  ? null
                                  : IconButton(
                                    tooltip: AppStrings.removeFromPlaylist,
                                    onPressed:
                                        () => music.removeFromPlaylist(
                                          playlistId,
                                          song.id,
                                        ),
                                    icon: Icon(
                                      Icons.remove_circle_outline_rounded,
                                      color: c.textDisabled,
                                      size: 20,
                                    ),
                                  ),
                        ),
                      ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    MusicProvider music,
    PlaylistItem playlist,
  ) {
    final ctrl = TextEditingController(text: playlist.name);
    final c = context.appColors;
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              AppStrings.rename,
              style: GoogleFonts.outfit(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.outfit(color: c.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: c.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.primary, width: 1),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppStrings.cancel,
                  style: GoogleFonts.outfit(color: c.textTertiary),
                ),
              ),
              TextButton(
                onPressed: () {
                  final name = ctrl.text.trim();
                  if (name.isNotEmpty) {
                    music.renamePlaylist(widget.playlistId, name);
                    Navigator.pop(context);
                  }
                },
                child: Text(
                  AppStrings.save,
                  style: GoogleFonts.outfit(
                    color: c.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    ).whenComplete(ctrl.dispose);
  }

  void _showAddSongsSheet(
    BuildContext context,
    MusicProvider music,
    PlaylistItem playlist,
  ) {
    final c = context.appColors;
    final existingIds = playlist.songs.map((s) => s.id).toSet();
    final available =
        music.allSongs.where((s) => !existingIds.contains(s.id)).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            expand: false,
            builder:
                (_, scrollCtrl) => _AddSongsSheet(
                  music: music,
                  playlist: playlist,
                  availableSongs: available,
                  scrollController: scrollCtrl,
                ),
          ),
    );
  }
}

class _AddSongsSheet extends StatefulWidget {
  const _AddSongsSheet({
    required this.music,
    required this.playlist,
    required this.availableSongs,
    required this.scrollController,
  });

  final MusicProvider music;
  final PlaylistItem playlist;
  final List<SongItem> availableSongs;
  final ScrollController scrollController;

  @override
  State<_AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends State<_AddSongsSheet> {
  late final TextEditingController _searchController;
  String _searchQuery = '';
  late final Map<int, String> _songSearchText;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _songSearchText = {
      for (final song in widget.availableSongs)
        song.id: vnNormalize(
          '${song.title}\u0000${song.artist}\u0000${song.album}',
        ),
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final query = vnNormalize(_searchQuery.trim());
    final songs =
        query.isEmpty
            ? widget.availableSongs
            : widget.availableSongs
                .where((song) {
                  final text = _songSearchText[song.id]!;
                  return text.contains(query);
                })
                .toList(growable: false);

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: c.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.addSongsTitle,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: GoogleFonts.outfit(color: c.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: AppStrings.searchHint,
              hintStyle: GoogleFonts.outfit(
                color: c.textDisabled,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: c.textTertiary,
                size: 20,
              ),
              suffixIcon:
                  _searchQuery.isEmpty
                      ? null
                      : IconButton(
                        tooltip: AppStrings.clearSearch,
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: c.textTertiary,
                          size: 18,
                        ),
                      ),
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
        Expanded(
          child:
              widget.availableSongs.isEmpty
                  ? Center(
                    child: Text(
                      AppStrings.allSongsAlreadyInPlaylist,
                      style: GoogleFonts.outfit(color: c.textTertiary),
                    ),
                  )
                  : songs.isEmpty
                  ? Center(
                    child: Text(
                      AppStrings.noResultsDot,
                      style: GoogleFonts.outfit(color: c.textTertiary),
                    ),
                  )
                  : ListView.builder(
                    controller: widget.scrollController,
                    key: const PageStorageKey<String>('add_playlist_songs'),
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return ListTile(
                        key: ValueKey('available_song_${song.id}'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 2,
                        ),
                        leading: SizedBox(
                          width: 44,
                          height: 44,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: QueryArtworkWidget(
                              id: song.albumId,
                              type: ArtworkType.ALBUM,
                              artworkFit: BoxFit.cover,
                              artworkBorder: BorderRadius.zero,
                              keepOldArtwork: true,
                              nullArtworkWidget: Container(
                                color: c.surfaceElevated,
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: c.textDisabled,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: c.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          style: GoogleFonts.outfit(
                            color: c.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(Icons.add_rounded, color: c.primary),
                        onTap: () {
                          widget.music.addToPlaylist(widget.playlist.id, song);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class _PlaylistSearchHeader extends SliverPersistentHeaderDelegate {
  const _PlaylistSearchHeader({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final c = context.appColors;
    return Container(
      color: c.background.withValues(alpha: 0.96),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.outfit(color: c.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: AppStrings.searchHint,
          hintStyle: GoogleFonts.outfit(color: c.textDisabled, fontSize: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: c.textTertiary,
            size: 20,
          ),
          suffixIcon:
              query.isEmpty
                  ? null
                  : IconButton(
                    tooltip: AppStrings.clearSearch,
                    onPressed: onClear,
                    icon: Icon(
                      Icons.close_rounded,
                      color: c.textTertiary,
                      size: 18,
                    ),
                  ),
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
    );
  }

  @override
  double get maxExtent => 64;

  @override
  double get minExtent => 64;

  @override
  bool shouldRebuild(covariant _PlaylistSearchHeader oldDelegate) =>
      oldDelegate.controller != controller || oldDelegate.query != query;
}

// ── Playlist header ───────────────────────────────────────

class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({required this.playlist});
  final PlaylistItem playlist;
  @override
  Widget build(BuildContext context) => LibraryDetailHeader(
    title: playlist.name,
    subtitle: AppStrings.songCount(playlist.songCount),
    artworkId: playlist.songs.firstOrNull?.albumId,
    type: ArtworkType.ALBUM,
    icon:
        playlist.id == MusicProvider.favoritesPlaylistId
            ? Icons.favorite_rounded
            : Icons.playlist_play_rounded,
  );
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) => LibraryDetailAction(
    label: label,
    icon: icon,
    onTap: onTap,
    primary: primary,
  );
}
