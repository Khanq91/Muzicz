import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../../models/playlist_item.dart';
import '../../models/song_item.dart';
import '../../providers/music_provider.dart';
import '../../providers/player_provider.dart';
import '../../screens/artist_detail_screen.dart';
import '../../screens/playlist_screen.dart';
import '../../theme/app_colors_data.dart';
import '../../utils/vietnamese_normalize.dart';
import '../app_bottom_navigation.dart';
import 'library_chrome.dart';
import 'library_empty_state.dart';
import 'library_preferences.dart';

class LibraryCollectionsPage extends StatefulWidget {
  const LibraryCollectionsPage({
    super.key,
    required this.section,
    required this.preferences,
    required this.onScanTap,
    required this.onClearSearch,
  });
  final LibrarySection section;
  final LibraryPreferences preferences;
  final VoidCallback onScanTap;
  final VoidCallback onClearSearch;

  @override
  State<LibraryCollectionsPage> createState() => _LibraryCollectionsPageState();
}

class _Collection {
  _Collection(this.id, this.name, this.songs, {this.createdAt, this.playlist});
  final String id;
  final String name;
  final List<SongItem> songs;
  final DateTime? createdAt;
  final PlaylistItem? playlist;
  late final int duration = songs.fold(0, (total, s) => total + s.duration);
  late final DateTime newest =
      createdAt ??
      songs.fold(
        DateTime(0),
        (date, song) =>
            song.dateAdded != null && song.dateAdded!.isAfter(date)
                ? song.dateAdded!
                : date,
      );
}

class _LibraryCollectionsPageState extends State<LibraryCollectionsPage>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  List<MapEntry<String, List<SongItem>>>? _artistSource;
  List<_Collection> _artists = [];
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    context.select<MusicProvider, List<Object?>>(
      (m) => [
        m.libraryRevision,
        m.librarySearchQuery,
        if (widget.section == LibrarySection.playlists) ...[
          m.favorites,
          for (final playlist in m.playlists)
            (
              playlist.id,
              playlist.name,
              playlist.songs.length,
              playlist.createdAt,
            ),
        ],
      ],
    );
    final music = context.read<MusicProvider>();
    final hasPlayer = context.select<PlayerProvider, bool>(
      (p) => p.currentSong != null,
    );
    final c = context.appColors;
    final playlists = widget.section == LibrarySection.playlists;
    if (!identical(_artistSource, music.sortedArtistGroups)) {
      _artistSource = music.sortedArtistGroups;
      _artists = [
        for (final entry in music.sortedArtistGroups)
          _Collection(entry.key, entry.key, entry.value),
      ];
    }
    final query = music.librarySearchQuery;
    final collections =
        (playlists
                ? [
                  for (final pl in [
                    music.favoritesPlaylist,
                    ...music.playlists,
                  ])
                    _Collection(
                      pl.id,
                      pl.name,
                      pl.songs,
                      createdAt: pl.createdAt,
                      playlist: pl,
                    ),
                ]
                : _artists)
            .where(
              (item) => query.isEmpty || vnNormalize(item.name).contains(query),
            )
            .toList();
    collections.sort((a, b) {
      // Favorites stays discoverable at the top, matching Muzicz's system playlist.
      if (a.id == b.id) return 0;
      if (a.id == MusicProvider.favoritesPlaylistId) return -1;
      if (b.id == MusicProvider.favoritesPlaylistId) return 1;
      var result = switch (widget.preferences.order(widget.section)) {
        LibraryOrder.name => vnNormalize(a.name).compareTo(vnNormalize(b.name)),
        LibraryOrder.newest => a.newest.compareTo(b.newest),
        LibraryOrder.duration => a.duration.compareTo(b.duration),
        LibraryOrder.count => a.songs.length.compareTo(b.songs.length),
      };
      if (result == 0) result = a.id.compareTo(b.id);
      return widget.preferences.descending(widget.section) ? -result : result;
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed:
                        playlists
                            ? _createPlaylist
                            : collections.isEmpty
                            ? null
                            : () {
                              final songs =
                                  collections
                                      .expand((c) => c.songs)
                                      .toSet()
                                      .toList();
                              context.read<PlayerProvider>().playSongsShuffled(
                                songs,
                              );
                            },
                    icon: Icon(
                      playlists ? Icons.add_rounded : Icons.shuffle_rounded,
                    ),
                    label: Text(
                      playlists ? AppStrings.create : AppStrings.shuffle,
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      backgroundColor: c.tertiary.withValues(alpha: .22),
                      foregroundColor: c.textPrimary,
                    ),
                  ),
                ),
              ),
              LibraryIconButton(
                icon: Icons.sort_rounded,
                tooltip: AppStrings.sort,
                onPressed:
                    () => showLibrarySheet(
                      context,
                      LibrarySortSheet(
                        preferences: widget.preferences,
                        section: widget.section,
                      ),
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            backgroundColor: c.surface,
            onRefresh: music.scanMusic,
            child: LibraryScrollbar(
              controller: _scroll,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  if (collections.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: AppBottomNavigation.scrollBottomPadding(
                            context,
                            hasMiniPlayer: hasPlayer,
                          ),
                        ),
                        child: LibraryEmptyState(
                          showSearchTip: query.isNotEmpty,
                          icon:
                              query.isNotEmpty
                                  ? Icons.search_off_rounded
                                  : widget.section.icon,
                          message:
                              query.isNotEmpty
                                  ? AppStrings.noResultsDot
                                  : AppStrings.noArtists,
                          onClearSearch:
                              query.isNotEmpty ? widget.onClearSearch : null,
                          onScanTap: query.isEmpty ? widget.onScanTap : null,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        0,
                        20,
                        AppBottomNavigation.scrollBottomPadding(
                          context,
                          hasMiniPlayer: hasPlayer,
                        ),
                      ),
                      sliver: SliverList.builder(
                        itemCount: collections.length,
                        itemBuilder: (context, index) {
                          final item = collections[index];
                          final isFavorite =
                              item.id == MusicProvider.favoritesPlaylistId;
                          return Padding(
                            key: ValueKey(item.id),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: libraryCardColor(context),
                              borderRadius: BorderRadius.circular(26),
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                minVerticalPadding: 12,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                leading: _CollectionCover(
                                  item: item,
                                  artist: !playlists,
                                  favorite: isFavorite,
                                ),
                                title: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: c.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  AppStrings.songCount(item.songs.length),
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing:
                                    playlists && !isFavorite
                                        ? IconButton.filledTonal(
                                          tooltip:
                                              AppStrings.libraryPlaylistOptions,
                                          style: IconButton.styleFrom(
                                            backgroundColor: c.surfaceElevated,
                                            foregroundColor: c.textPrimary,
                                          ),
                                          onPressed:
                                              () => _playlistOptions(
                                                item.playlist!,
                                              ),
                                          icon: const Icon(
                                            Icons.more_vert_rounded,
                                          ),
                                        )
                                        : Icon(
                                          isFavorite
                                              ? Icons.favorite_rounded
                                              : Icons.chevron_right_rounded,
                                          color:
                                              isFavorite
                                                  ? c.tertiary
                                                  : c.textTertiary,
                                        ),
                                onTap:
                                    () => Navigator.of(context).push(
                                      libraryDetailRoute(
                                        context,
                                        playlists
                                            ? PlaylistDetailScreen(
                                              playlistId: item.id,
                                            )
                                            : ArtistDetailScreen(
                                              artistName: item.name,
                                              songs: item.songs,
                                            ),
                                      ),
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createPlaylist() async {
    final name = await _nameDialog(AppStrings.createPlaylist);
    if (!mounted || name == null) return;
    final playlist = await context.read<MusicProvider>().createPlaylist(name);
    if (!mounted) return;
    Navigator.of(context).push(
      libraryDetailRoute(
        context,
        PlaylistDetailScreen(playlistId: playlist.id),
      ),
    );
  }

  Future<String?> _nameDialog(String title, [String initial = '']) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(
                hintText: AppStrings.playlistNameHint,
              ),
              onSubmitted: (name) {
                if (name.trim().isNotEmpty) Navigator.pop(context, name.trim());
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(AppStrings.cancel),
              ),
              TextButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.pop(context, controller.text.trim());
                  }
                },
                child: const Text(AppStrings.save),
              ),
            ],
          ),
    );
    // Dialog route finishes its closing animation after its result completes.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    return result;
  }

  Future<void> _playlistOptions(PlaylistItem playlist) async {
    final action = await showLibrarySheet<String>(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              playlist.name,
              style: TextStyle(
                fontSize: 22,
                color: context.appColors.textPrimary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text(AppStrings.rename),
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text(AppStrings.delete),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'rename') {
      final name = await _nameDialog(AppStrings.rename, playlist.name);
      if (mounted && name != null) {
        await context.read<MusicProvider>().renamePlaylist(playlist.id, name);
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(AppStrings.deletePlaylistTitle(playlist.name)),
              content: const Text(AppStrings.deletePlaylistBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(AppStrings.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(AppStrings.delete),
                ),
              ],
            ),
      );
      if (mounted && confirmed == true) {
        await context.read<MusicProvider>().deletePlaylist(playlist.id);
      }
    }
  }
}

class _CollectionCover extends StatelessWidget {
  const _CollectionCover({
    required this.item,
    required this.artist,
    required this.favorite,
  });
  final _Collection item;
  final bool artist;
  final bool favorite;
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final placeholder = ColoredBox(
      color: c.primary.withValues(alpha: .12),
      child: Center(
        child: Icon(
          favorite
              ? Icons.favorite_rounded
              : artist
              ? Icons.person_rounded
              : Icons.playlist_play_rounded,
          color: favorite ? c.tertiary : c.primary,
          size: 28,
        ),
      ),
    );
    return SizedBox(
      width: 52,
      height: 52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(artist ? 26 : 16),
        child:
            favorite || item.songs.isEmpty
                ? placeholder
                : QueryArtworkWidget(
                  id:
                      artist
                          ? item.songs.first.artistId
                          : item.songs.first.albumId,
                  type: artist ? ArtworkType.ARTIST : ArtworkType.ALBUM,
                  artworkWidth: 52,
                  artworkHeight: 52,
                  artworkBorder: BorderRadius.zero,
                  keepOldArtwork: true,
                  nullArtworkWidget: placeholder,
                ),
      ),
    );
  }
}
