import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../models/song_item.dart';
import '../../providers/player_provider.dart';
import '../../providers/music_provider.dart';
import '../../theme/app_colors_data.dart';
import 'sheets/album_songs_sheet.dart';

class AlbumCarousel extends StatefulWidget {
  const AlbumCarousel({super.key, required this.player});
  final PlayerProvider player;
  @override
  State<AlbumCarousel> createState() => _AlbumCarouselState();
}

class _AlbumCarouselState extends State<AlbumCarousel> {
  late final PageController _pages;
  bool _userDrag = false;
  bool _scheduled = false;
  int? _lastSongId;
  int _target = 0;
  @override
  void initState() {
    super.initState();
    _target = widget.player.currentQueueIndex;
    _lastSongId = widget.player.currentSong?.id;
    _pages = PageController(initialPage: _target);
  }

  void _sync() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_pages.hasClients || _userDrag) return;
      final player = widget.player;
      final index = player.currentQueueIndex;
      if (player.queue.isEmpty || index >= player.queue.length) return;
      final movedSameSong = _lastSongId == player.currentSong?.id;
      if (index != _target) {
        _target = index;
        if (movedSameSong || MediaQuery.disableAnimationsOf(context)) {
          _pages.jumpToPage(index);
        } else {
          _pages.animateToPage(
            index,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        }
      }
      _lastSongId = player.currentSong?.id;
    });
  }

  Future<void> _settled() async {
    if (!_userDrag || !_pages.hasClients) return;
    _userDrag = false;
    final index = (_pages.page ?? 0).round();
    _target = index;
    if (index != widget.player.currentQueueIndex &&
        index < widget.player.queue.length) {
      HapticFeedback.selectionClick();
      try {
        await widget.player.skipToIndex(index);
      } finally {
        if (mounted) _sync();
      }
    } else {
      _sync();
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Separate selectors let Provider compare the queue contents rather than
    // a record containing a new List identity on every player notification.
    final queue = context.select<PlayerProvider, List<SongItem>>(
      (p) => List<SongItem>.of(p.queue),
    );
    context.select<PlayerProvider, int>((p) => p.currentQueueIndex);
    final playing = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    _sync();
    return AnimatedScale(
      scale: playing ? 1 : .95,
      duration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _userDrag = true;
          }
          if (notification is ScrollEndNotification && _userDrag) _settled();
          return false;
        },
        child: PageView.builder(
          key: const ValueKey('album-carousel'),
          controller: _pages,
          itemCount: queue.length,
          physics: const PageScrollPhysics(),
          itemBuilder: (context, index) {
            final song = queue[index];
            final art = RepaintBoundary(
              child: QueryArtworkWidget(
                key: ValueKey((song.id, song.albumId)),
                id: song.albumId,
                type: ArtworkType.ALBUM,
                artworkBorder: BorderRadius.zero,
                artworkFit: BoxFit.cover,
                keepOldArtwork: true,
                nullArtworkWidget: ColoredBox(
                  color: context.appColors.surfaceElevated,
                  child: Center(
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 88,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: LayoutBuilder(
                builder:
                    (_, size) => AnimatedBuilder(
                      animation: _pages,
                      child: art,
                      builder: (_, child) {
                        final offset =
                            _pages.hasClients &&
                                    _pages.position.hasContentDimensions
                                ? ((_pages.page ?? _target.toDouble()) - index)
                                    .clamp(-1.0, 1.0)
                                : 0.0;
                        return Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox(
                              width: size.maxWidth * (1 - offset.abs() * .12),
                              height: size.maxHeight,
                              child: OverflowBox(
                                maxWidth: size.maxWidth,
                                minWidth: size.maxWidth,
                                child: Transform.translate(
                                  offset: Offset(
                                    offset * size.maxWidth * .12,
                                    0,
                                  ),
                                  child: GestureDetector(
                                    onTap:
                                        () => showAlbumSongsSheet(
                                          context,
                                          context.read<MusicProvider>(),
                                          song,
                                        ),
                                    child: SizedBox(
                                      width: size.maxWidth,
                                      height: size.maxHeight,
                                      child: child,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ),
            );
          },
        ),
      ),
    );
  }
}
