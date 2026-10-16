import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../core/app_strings.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors_data.dart';
import '../widgets/library/library_chrome.dart';
import '../widgets/music_list_tile.dart';

class ArtistDetailScreen extends StatefulWidget {
  const ArtistDetailScreen({
    super.key,
    required this.artistName,
    required this.songs,
  });
  final String artistName;
  final List<SongItem> songs;
  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  final _scroll = ScrollController();
  final _collapsed = <String>{};
  List<SongItem>? _source;
  List<MapEntry<String, List<SongItem>>> _albums = [];
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.select<MusicProvider, int>((m) => m.libraryRevision);
    final music = context.read<MusicProvider>();
    final songs = music.artistMap[widget.artistName] ?? widget.songs;
    if (!identical(_source, songs)) {
      _source = songs;
      final albums = <String, List<SongItem>>{};
      for (final song in songs) {
        albums.putIfAbsent(song.album, () => []).add(song);
      }
      _albums = albums.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    }
    final c = context.appColors;
    final player = context.read<PlayerProvider>();
    return Scaffold(
      backgroundColor: c.surface,
      body: RefreshIndicator(
        onRefresh: music.scanMusic,
        child: LibraryScrollbar(
          controller: _scroll,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: c.surface,
                title: Text(
                  widget.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                leading: IconButton(
                  tooltip: AppStrings.back,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: LibraryDetailHeader(
                    title: widget.artistName,
                    subtitle: AppStrings.artistStats(
                      songs.length,
                      _albums.length,
                    ),
                    artworkId: songs.firstOrNull?.artistId,
                    type: ArtworkType.ARTIST,
                    icon: Icons.person_rounded,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: LibraryDetailAction(
                          label: AppStrings.playAll,
                          icon: Icons.play_arrow_rounded,
                          primary: true,
                          onTap: () => player.playSongs(songs),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LibraryDetailAction(
                          label: AppStrings.shuffle,
                          icon: Icons.shuffle_rounded,
                          primary: false,
                          onTap: () => player.playSongsShuffled(songs),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: LibraryDetailAction(
                          label: AppStrings.shuffleLoop,
                          icon: Icons.all_inclusive_rounded,
                          primary: false,
                          onTap: () => player.enableShuffleLoop(songs),
                        ),
                      ),
                      IconButton(
                        tooltip: AppStrings.shuffleLoopInfo,
                        onPressed:
                            () => showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text(AppStrings.shuffleLoop),
                                    content: const Text(
                                      AppStrings.shuffleLoopDescription,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          AppStrings.libraryDone,
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
                        icon: Icon(
                          Icons.info_outline_rounded,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    AppStrings.allSongsWithCount(songs.length),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ),
              for (final album in _albums)
                SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 20, 4),
                        child: Material(
                          color: c.primary.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(24),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: QueryArtworkWidget(
                                id: album.value.first.albumId,
                                type: ArtworkType.ALBUM,
                                artworkWidth: 48,
                                artworkHeight: 48,
                                keepOldArtwork: true,
                                nullArtworkWidget: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(
                                    Icons.album_outlined,
                                    color: c.primary,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              album.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              AppStrings.songCount(album.value.length),
                              style: TextStyle(color: c.textSecondary),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: AppStrings.playAll,
                                  onPressed:
                                      () => player.playSongs(
                                        album.value,
                                        sourceName: album.key,
                                      ),
                                  icon: Icon(
                                    Icons.play_arrow_rounded,
                                    color: c.primary,
                                  ),
                                ),
                                AnimatedRotation(
                                  turns:
                                      _collapsed.contains(album.key) ? -.25 : 0,
                                  duration: libraryMotion(context, 220),
                                  child: const Icon(Icons.expand_more_rounded),
                                ),
                              ],
                            ),
                            onTap:
                                () => setState(() {
                                  if (!_collapsed.add(album.key)) {
                                    _collapsed.remove(album.key);
                                  }
                                }),
                          ),
                        ),
                      ),
                    ),
                    if (!_collapsed.contains(album.key))
                      SliverList.builder(
                        itemCount: album.value.length,
                        itemBuilder: (context, index) {
                          final song = album.value[index];
                          return Padding(
                            key: ValueKey(song.id),
                            padding: const EdgeInsets.fromLTRB(14, 0, 20, 6),
                            child: Selector<PlayerProvider, bool>(
                              selector: (_, p) => p.currentSong?.id == song.id,
                              builder:
                                  (_, active, _) => MusicListTile(
                                    song: song,
                                    libraryStyle: true,
                                    isActive: active,
                                    onTap:
                                        () => player.playSongs(
                                          songs,
                                          specificSong: song,
                                        ),
                                  ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
