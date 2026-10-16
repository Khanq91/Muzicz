import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_strings.dart';
import '../../models/song_item.dart';
import '../../providers/music_provider.dart';
import '../../providers/player_provider.dart';
import '../../theme/app_colors_data.dart';
import '../app_bottom_navigation.dart';
import '../music_list_tile.dart';
import 'bulk_playlist_sheet.dart';
import 'library_chrome.dart';
import 'library_empty_state.dart';
import 'library_preferences.dart';
import 'selection_header.dart';

class LibrarySongsPage extends StatefulWidget {
  const LibrarySongsPage({
    super.key,
    required this.preferences,
    required this.onScanTap,
    required this.onClearSearch,
    this.folders = false,
    this.active = true,
  });
  final LibraryPreferences preferences;
  final VoidCallback onScanTap;
  final VoidCallback onClearSearch;
  final bool folders;
  final bool active;

  @override
  State<LibrarySongsPage> createState() => _LibrarySongsPageState();
}

class _LibrarySongsPageState extends State<LibrarySongsPage>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _selected = <int>{};
  bool _selecting = false;
  String _path = '/';
  int _folderDirection = 1;
  final _folderOffsets = <String, double>{};
  List<SongItem>? _indexedSongs;
  Map<String, LibraryFolder> _folders = {};
  List<SongItem>? _sortSource;
  LibraryOrder? _lastOrder;
  bool? _lastDescending;
  List<SongItem> _sortedSongs = [];
  double _itemExtent = 80;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _navigate(String path) {
    if (_scroll.hasClients) _folderOffsets[_path] = _scroll.offset;
    _folderDirection = path.startsWith(_path == '/' ? '/' : '$_path/') ? 1 : -1;
    setState(() {
      _path = path;
      _selected.clear();
      _selecting = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(
          (_folderOffsets[path] ?? 0).clamp(
            0,
            _scroll.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  void _cancelSelection() => setState(() {
    _selected.clear();
    _selecting = false;
  });

  Future<void> _refresh() async {
    await context.read<MusicProvider>().scanMusic();
  }

  Future<void> _locate(SongItem song) async {
    widget.onClearSearch();
    // Clearing a query rebuilds the full folder index before resolving a
    // cross-folder destination that may have been absent from search results.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (widget.folders) {
      final parent = libraryParentPath(song.data);
      if (!_folders.containsKey(parent)) return;
      _navigate(parent);
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scroll.hasClients) return;
    final index = _sortedSongs.indexWhere((s) => s.id == song.id);
    if (index < 0) return;
    final folderCount =
        widget.folders ? _folders[_path]?.children.length ?? 0 : 0;
    await _scroll.animateTo(
      ((index + folderCount) * _itemExtent).clamp(
        0,
        _scroll.position.maxScrollExtent,
      ),
      duration: libraryMotion(context, 380),
      curve: Curves.easeOutCubic,
    );
  }

  List<SongItem> _sort(List<SongItem> songs, LibrarySection section) {
    final order = widget.preferences.order(section);
    final descending = widget.preferences.descending(section);
    if (!identical(songs, _sortSource) ||
        order != _lastOrder ||
        descending != _lastDescending) {
      _sortSource = songs;
      _lastOrder = order;
      _lastDescending = descending;
      _sortedSongs = orderLibrarySongs(songs, order, descending);
    }
    return _sortedSongs;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    context.select<MusicProvider, int>((m) => m.libraryRevision);
    // Playback position and play counts do not invalidate the library snapshot.
    final allSongs = context.select<MusicProvider, List<SongItem>>(
      (m) => m.allSongs,
    );
    final filtered = context.select<MusicProvider, List<SongItem>>(
      (m) => m.libraryFilteredSongs,
    );
    final query = context.select<MusicProvider, String>(
      (m) => m.librarySearchQuery,
    );
    final current = context.select<PlayerProvider, SongItem?>(
      (p) => p.currentSong,
    );
    final c = context.appColors;
    _itemExtent =
        80 +
        (MediaQuery.textScalerOf(context).scale(15) - 15).clamp(0, 60) * 2.5;
    final section =
        widget.folders ? LibrarySection.folders : LibrarySection.songs;
    if (widget.folders && !identical(_indexedSongs, filtered)) {
      _indexedSongs = filtered;
      _folders = buildLibraryFolders(filtered);
      if (!_folders.containsKey(_path)) _path = '/';
    }
    final folder = _folders[_path];
    final songs = _sort(
      widget.folders ? folder?.songs ?? const [] : filtered,
      section,
    );
    final childFolders =
        widget.folders
            ? (folder?.children.values.toList() ?? <LibraryFolder>[])
            : <LibraryFolder>[];
    childFolders.sort((a, b) {
      final order = widget.preferences.order(section);
      final comparison = switch (order) {
        LibraryOrder.count => a.totalSongs.compareTo(b.totalSongs),
        LibraryOrder.duration => a.totalDuration.compareTo(b.totalDuration),
        LibraryOrder.newest => a.newest.compareTo(b.newest),
        LibraryOrder.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
      };
      return widget.preferences.descending(section) ? -comparison : comparison;
    });
    final visibleIds = songs.map((s) => s.id).toSet();
    _selected.removeWhere((id) => !visibleIds.contains(id));
    final bottom = AppBottomNavigation.scrollBottomPadding(
      context,
      hasMiniPlayer: current != null,
    );

    return PopScope(
      canPop:
          !widget.active || (!_selecting && (!widget.folders || _path == '/')),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !widget.active) return;
        if (_selecting) {
          _cancelSelection();
        } else {
          _navigate(libraryParentPath(_path));
        }
      },
      child: Column(
        children: [
          AnimatedSize(
            duration: libraryMotion(context, 220),
            child:
                _selecting
                    ? SelectionHeader(
                      count: _selected.length,
                      total: songs.length,
                      onCancel: _cancelSelection,
                      onToggleSelectAll:
                          () => setState(() {
                            if (_selected.length == songs.length) {
                              _selected.clear();
                            } else {
                              _selected.addAll(visibleIds);
                            }
                          }),
                    )
                    : Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child:
                                widget.folders
                                    ? _breadcrumbs(context)
                                    : Align(
                                      alignment: Alignment.centerLeft,
                                      child: FilledButton.tonalIcon(
                                        onPressed:
                                            songs.isEmpty
                                                ? null
                                                : () => context
                                                    .read<PlayerProvider>()
                                                    .playSongsShuffled(songs),
                                        icon: const Icon(
                                          Icons.shuffle_rounded,
                                          size: 22,
                                        ),
                                        label: Text(AppStrings.shuffle),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 48),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                          ),
                                          backgroundColor: c.tertiary
                                              .withValues(alpha: .22),
                                          foregroundColor: c.textPrimary,
                                        ),
                                      ),
                                    ),
                          ),
                          if (current != null &&
                              allSongs.any((s) => s.id == current.id)) ...[
                            LibraryIconButton(
                              icon: Icons.my_location_rounded,
                              tooltip: AppStrings.libraryLocate,
                              connected: true,
                              onPressed: () => _locate(current),
                            ),
                            const SizedBox(width: 4),
                          ],
                          LibraryIconButton(
                            icon: Icons.sort_rounded,
                            tooltip: AppStrings.sort,
                            onPressed:
                                () => showLibrarySheet(
                                  context,
                                  LibrarySortSheet(
                                    preferences: widget.preferences,
                                    section: section,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
          ),
          if (_selecting)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed:
                      _selected.isEmpty
                          ? null
                          : () => _showSelectionActions(
                            songs
                                .where((s) => _selected.contains(s.id))
                                .toList(),
                          ),
                  icon: const Icon(Icons.more_horiz_rounded),
                  label: const Text(AppStrings.libraryActions),
                ),
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: libraryMotion(context, 220),
              transitionBuilder:
                  (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: Offset(
                          widget.folders ? .12 * _folderDirection : 0,
                          0,
                        ),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: child,
                    ),
                  ),
              // Only the incoming scroll view owns the controller during a folder
              // transition. The outgoing list is removed to avoid double attachment.
              layoutBuilder:
                  (current, previous) => current ?? const SizedBox.shrink(),
              child: RefreshIndicator(
                key: ValueKey(widget.folders ? _path : 'songs'),
                onRefresh: _refresh,
                color: c.primary,
                backgroundColor: c.surface,
                child: LibraryScrollbar(
                  controller: _scroll,
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: [
                      if (songs.isEmpty && childFolders.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: bottom),
                            child: LibraryEmptyState(
                              showSearchTip: query.isNotEmpty,
                              icon:
                                  query.isEmpty
                                      ? section.icon
                                      : Icons.search_off_rounded,
                              message:
                                  query.isEmpty
                                      ? AppStrings.emptyLibrary
                                      : AppStrings.noResultsDot,
                              onScanTap:
                                  query.isEmpty ? widget.onScanTap : null,
                              onClearSearch:
                                  query.isNotEmpty
                                      ? widget.onClearSearch
                                      : null,
                            ),
                          ),
                        )
                      else ...[
                        SliverFixedExtentList(
                          itemExtent: _itemExtent,
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index < childFolders.length) {
                                final folder = childFolders[index];
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    0,
                                    20,
                                    8,
                                  ),
                                  child: Material(
                                    color: libraryCardColor(context),
                                    borderRadius: BorderRadius.circular(26),
                                    clipBehavior: Clip.antiAlias,
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 4,
                                          ),
                                      leading: CircleAvatar(
                                        backgroundColor: c.primary.withValues(
                                          alpha: .13,
                                        ),
                                        child: Icon(
                                          Icons.folder_outlined,
                                          color: c.primary,
                                        ),
                                      ),
                                      title: Text(
                                        folder.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: c.textPrimary),
                                      ),
                                      subtitle: Text(
                                        AppStrings.songCount(folder.totalSongs),
                                        style: TextStyle(
                                          color: c.textSecondary,
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.chevron_right_rounded,
                                        color: c.textTertiary,
                                      ),
                                      onTap: () => _navigate(folder.path),
                                    ),
                                  ),
                                );
                              }
                              final song = songs[index - childFolders.length];
                              return Padding(
                                key: ValueKey(song.id),
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  0,
                                  20,
                                  8,
                                ),
                                child: Selector<PlayerProvider, bool>(
                                  selector:
                                      (_, player) =>
                                          player.currentSong?.id == song.id,
                                  builder:
                                      (context, active, _) => MusicListTile(
                                        song: song,
                                        libraryStyle: true,
                                        isActive: active,
                                        isSelecting: _selecting,
                                        isSelected: _selected.contains(song.id),
                                        onLongPress:
                                            () => setState(() {
                                              _selecting = true;
                                              _selected.add(song.id);
                                            }),
                                        onTap: () {
                                          if (_selecting) {
                                            setState(() {
                                              if (!_selected.add(song.id)) {
                                                _selected.remove(song.id);
                                              }
                                            });
                                          } else {
                                            context
                                                .read<PlayerProvider>()
                                                .playSongs(
                                                  songs,
                                                  specificSong: song,
                                                );
                                          }
                                        },
                                      ),
                                ),
                              );
                            },
                            childCount: childFolders.length + songs.length,
                            findChildIndexCallback: (key) {
                              if (key is! ValueKey<int>) return null;
                              final index = songs.indexWhere(
                                (s) => s.id == key.value,
                              );
                              return index < 0
                                  ? null
                                  : childFolders.length + index;
                            },
                          ),
                        ),
                        SliverToBoxAdapter(child: SizedBox(height: bottom)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breadcrumbs(BuildContext context) {
    final parts = _path.split('/').where((p) => p.isNotEmpty).toList();
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: [
            if (_path != '/')
              IconButton(
                tooltip: AppStrings.back,
                onPressed: () => _navigate(libraryParentPath(_path)),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
            TextButton(
              onPressed: () => _navigate('/'),
              child: const Text(AppStrings.libraryDevice),
            ),
            for (var i = 0; i < parts.length; i++) ...[
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: context.appColors.textTertiary,
              ),
              TextButton(
                onPressed: () => _navigate('/${parts.take(i + 1).join('/')}'),
                child: Text(parts[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showSelectionActions(List<SongItem> songs) async {
    final action = await showLibrarySheet<String>(
      context,
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                AppStrings.selectedCount(songs.length),
                style: TextStyle(
                  fontSize: 22,
                  color: context.appColors.textPrimary,
                ),
              ),
            ),
            for (final item in [
              ('play', Icons.play_arrow_rounded, AppStrings.playAll),
              ('next', Icons.playlist_play_rounded, AppStrings.playNext),
              ('queue', Icons.queue_music_rounded, AppStrings.addToQueue),
              (
                'playlist',
                Icons.playlist_add_rounded,
                AppStrings.addToPlaylist,
              ),
              (
                'favorite',
                Icons.favorite_outline_rounded,
                AppStrings.favorites,
              ),
              (
                'hide',
                Icons.visibility_off_rounded,
                AppStrings.hideFromLibrary,
              ),
            ])
              ListTile(
                leading: Icon(item.$2, color: context.appColors.primary),
                title: Text(
                  item.$3,
                  style: TextStyle(color: context.appColors.textPrimary),
                ),
                onTap: () => Navigator.pop(context, item.$1),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final music = context.read<MusicProvider>();
    final player = context.read<PlayerProvider>();
    switch (action) {
      case 'play':
        await player.playSongs(songs);
      case 'next':
        if (player.currentSong == null) {
          await player.playSongs(songs);
        } else {
          for (final song in songs.reversed) {
            await player.insertNext(song);
          }
        }
      case 'queue':
        if (player.currentSong == null) {
          await player.playSongs(songs);
        } else {
          for (final song in songs) {
            await player.addToQueue(song);
          }
        }
      case 'favorite':
        await music.bulkFavoriteToggle(songs.map((s) => s.id).toList());
      case 'playlist':
        await showLibrarySheet(context, BulkPlaylistSheet(songs: songs));
      case 'hide':
        final confirmed = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text(AppStrings.libraryHideSelected),
                content: const Text(AppStrings.hideSongsBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(AppStrings.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(AppStrings.hide),
                  ),
                ],
              ),
        );
        if (confirmed != true) return;
        await music.hideSongsFromLibrary(songs);
    }
    if (mounted) _cancelSelection();
  }
}
