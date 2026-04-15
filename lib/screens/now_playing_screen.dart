import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../services/audio_handler.dart';
import '../theme/app_colors.dart';
import '../widgets/add_to_playlist_sheet.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _artRotateCtrl;
  late final AnimationController _appearCtrl;
  bool _queueVisible = false;
  // FIX 1: Track whether queue sheet has finished animating open
  bool _queueFullyOpen = false;

  @override
  void initState() {
    super.initState();

    _artRotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    _appearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    final player = context.read<PlayerProvider>();
    if (player.isPlaying) _artRotateCtrl.repeat();
    player.addListener(_onPlayerChange);
  }

  void _onPlayerChange() {
    final player = context.read<PlayerProvider>();
    if (player.isPlaying) {
      if (!_artRotateCtrl.isAnimating) _artRotateCtrl.repeat();
    } else {
      _artRotateCtrl.stop();
    }
  }

  @override
  void dispose() {
    _artRotateCtrl.dispose();
    _appearCtrl.dispose();
    context.read<PlayerProvider>().removeListener(_onPlayerChange);
    super.dispose();
  }

  void _openQueue() {
    setState(() {
      _queueVisible = true;
      _queueFullyOpen = false; // reset — sẽ set true sau khi animation done
    });
    HapticFeedback.lightImpact();
  }

  void _closeQueue() {
    setState(() {
      _queueVisible = false;
      _queueFullyOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;
    final c = context.appColors;
    if (song == null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
    }

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 400) Navigator.pop(context);
        if ((d.primaryVelocity ?? 0) < -400 && !_queueVisible) _openQueue();
      },
      onHorizontalDragEnd: (d) {
        if (d.primaryVelocity == null) return;
        if (d.primaryVelocity! < -300) {
          player.skipToNext();
          HapticFeedback.selectionClick();
        }
        if (d.primaryVelocity! > 300) {
          player.skipToPrevious();
          HapticFeedback.selectionClick();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: _BlurredBackground(albumId: song.albumId),
            ),
            Positioned.fill(
              child: Container(color: c.scrimDark),
            ),
            SafeArea(
              child: FadeTransition(
                opacity:
                CurvedAnimation(parent: _appearCtrl, curve: Curves.easeOut),
                child: Column(
                  children: [
                    _TopBar(song: song),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Column(
                        children: [
                          _AlbumArtSection(
                              song: song, rotateCtrl: _artRotateCtrl),
                          const SizedBox(height: 28),
                          _SongInfo(song: song),
                          const SizedBox(height: 20),
                          _ProgressSection(player: player),
                          const SizedBox(height: 20),
                          _ControlsSection(player: player),
                          const SizedBox(height: 16),
                          _ExtraActions(
                            player: player,
                            onQueueTap: () {
                              if (_queueVisible) {
                                _closeQueue();
                              } else {
                                _openQueue();
                              }
                            },
                            queueVisible: _queueVisible,
                          ),
                          const SizedBox(height: 12),
                          if (!_queueVisible)
                            _SwipeHint(onTap: _openQueue),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // FIX 1: AnimatedPositioned + onEnd callback để track trạng thái
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              onEnd: () {
                // Sheet đã đứng yên → bật blur
                if (_queueVisible) {
                  setState(() => _queueFullyOpen = true);
                }
              },
              bottom: _queueVisible
                  ? 0
                  : -MediaQuery.of(context).size.height * 0.6,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.6,
              child: RepaintBoundary(
                child: _QueueSheet(
                  player: player,
                  onClose: _closeQueue,
                  // FIX 1: chỉ bật blur khi sheet đã fully open
                  useBlur: _queueFullyOpen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Swipe hint ────────────────────────────────────────────────────────────────

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(Icons.keyboard_arrow_up_rounded,
              color: c.onPlayerMinimal, size: 20),
          Text('Hàng chờ',
              style: GoogleFonts.outfit(fontSize: 11, color: c.onPlayerMinimal)),
        ],
      ),
    );
  }
}

// ── Blurred background ────────────────────────────────────────────────────────

class _BlurredBackground extends StatelessWidget {
  const _BlurredBackground({required this.albumId});
  final int albumId;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
            decoration: BoxDecoration(
                gradient: c.backgroundGradient)),
        QueryArtworkWidget(
          id: albumId,
          type: ArtworkType.ALBUM,
          artworkFit: BoxFit.cover,
          artworkBorder: BorderRadius.zero,
          keepOldArtwork: true,
          nullArtworkWidget: const SizedBox.shrink(),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.song});
  final SongItem song;

  @override
  Widget build(BuildContext context) {
    final music = context.read<MusicProvider>();
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                size: 32, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'ĐANG PHÁT',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                    color: Colors.white54,
                    letterSpacing: 2.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => _navigateToAlbum(context, music, song),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.album.isNotEmpty ? song.album : 'Từ thư viện',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.onPlayerHigh,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white38,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 9, color: c.onPlayerSubtle),
                    ],
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                size: 24, color: Colors.white),
            color: c.card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              switch (val) {
                case 'fav':
                  context.read<MusicProvider>().toggleFavorite(song.id);
                  break;
                case 'playlist':
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => ChangeNotifierProvider.value(
                      value: context.read<MusicProvider>(),
                      child: AddToPlaylistSheet(song: song),
                    ),
                  );
                  break;
                case 'info':
                  _showSongInfo(context, song);
                  break;
                case 'share':
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chia sẻ: ${song.title}'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: c.surfaceElevated,
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (_) {
              final isFav =
              context.read<MusicProvider>().isFavorite(song.id);
              return [
                _popItem(
                  context,
                  'fav',
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  isFav ? 'Bỏ yêu thích' : 'Yêu thích',
                  iconColor: isFav ? c.tertiary : null,
                ),
                _popItem(context,'playlist', Icons.playlist_add_rounded,
                    'Thêm vào danh sách phát'),
                _popItem(context,'share', Icons.share_rounded, 'Chia sẻ'),
                _popItem(context,'info', Icons.info_outline_rounded,
                    'Thông tin bài hát'),
              ];
            },
          ),
        ],
      ),
    );
  }

  void _navigateToAlbum(
      BuildContext context, MusicProvider music, SongItem song) {
    final albumSongs = music.albumMap[song.album] ?? [];
    if (albumSongs.isEmpty) return;
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Column(
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: QueryArtworkWidget(
                        id: song.albumId,
                        type: ArtworkType.ALBUM,
                        artworkFit: BoxFit.cover,
                        artworkBorder: BorderRadius.zero,
                        keepOldArtwork: true,
                        nullArtworkWidget: Container(
                          color: c.surfaceElevated,
                          child: Icon(Icons.album_rounded,
                              color: c.textDisabled),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.album,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          '${albumSongs.length} bài hát',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: c.divider),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: albumSongs.length,
                itemBuilder: (_, i) {
                  final s = albumSongs[i];
                  final isCurrentSong = s.id == song.id;
                  return ListTile(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    leading: isCurrentSong
                        ? Icon(Icons.equalizer_rounded,
                        color: c.primary, size: 24)
                        : Text(
                      '${i + 1}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: c.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    title: Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: isCurrentSong
                            ? c.primary
                            : c.textPrimary,
                        fontWeight: isCurrentSong
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      s.durationFormatted,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: c.textTertiary),
                    ),
                    onTap: () {
                      final player = context.read<PlayerProvider>();
                      player.playSongs(albumSongs, specificSong: s);
                      music.onSongPlayed(s.id);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _popItem(BuildContext context, String val, IconData icon, String label,
      {Color? iconColor}) {
    final c = context.appColors;
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? c.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.outfit(
                  color: c.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }

  void _showSongInfo(BuildContext context, SongItem song) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thông tin bài hát',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary)),
            const SizedBox(height: 16),
            _infoRow(context,'Tên bài', song.title),
            _infoRow(context,'Nghệ sĩ', song.artist),
            _infoRow(context,'Album', song.album),
            _infoRow(context,'Thời lượng', song.durationFormatted),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: GoogleFonts.outfit(
                    color: c.textTertiary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.outfit(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── Album art ─────────────────────────────────────────────────────────────────

class _AlbumArtSection extends StatelessWidget {
  const _AlbumArtSection({required this.song, required this.rotateCtrl});
  final SongItem song;
  final AnimationController rotateCtrl;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.70;
    final c = context.appColors;
    return Center(
      child: AnimatedBuilder(
        animation: rotateCtrl,
        builder: (_, child) => Transform.rotate(
          angle: rotateCtrl.value * 2 * 3.14159,
          child: child,
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: c.primary.withOpacity(0.3),
                  blurRadius: 60,
                  offset: const Offset(0, 20)),
              BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 16)),
            ],
          ),
          child: ClipOval(
            child: QueryArtworkWidget(
              id: song.albumId,
              type: ArtworkType.ALBUM,
              artworkFit: BoxFit.cover,
              artworkBorder: BorderRadius.zero,
              keepOldArtwork: true,
              nullArtworkWidget: Container(
                decoration:
                BoxDecoration(gradient: c.primaryGradient),
                child: const Icon(Icons.music_note_rounded,
                    color: Colors.white54, size: 80),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Song info + favorite ──────────────────────────────────────────────────────

class _SongInfo extends StatelessWidget {
  const _SongInfo({required this.song});
  final SongItem song;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final isFav = music.isFavorite(song.id);
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${song.artist} · ${song.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: c.onPlayerMedium,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<MusicProvider>(),
                  child: AddToPlaylistSheet(song: song),
                ),
              );
            },
            icon: Icon(Icons.playlist_add_rounded,
                color: c.onPlayerLow, size: 26),
          ),
          IconButton(
            onPressed: () {
              music.toggleFavorite(song.id);
              HapticFeedback.selectionClick();
            },
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isFav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey(isFav),
                color: isFav ? c.tertiary : c.onPlayerLow,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress ──────────────────────────────────────────────────────────────────

class _ProgressSection extends StatefulWidget {
  const _ProgressSection({required this.player});
  final PlayerProvider player;

  @override
  State<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<_ProgressSection> {
  double? _dragValue; // null = không drag; có giá trị = đang kéo
  int _cachedDurMs = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PositionData>(
      stream: widget.player.positionDataStream,
      builder: (_, snap) {
        final data = snap.data ??
            const PositionData(Duration.zero, Duration.zero, Duration.zero);

        final durMs = data.duration.inMilliseconds;
        if (durMs > 0) _cachedDurMs = durMs; // cache lại khi có giá trị

        // Khi đang drag → dùng local value; ngược lại dùng stream
        final progress = _dragValue ??
            (_cachedDurMs > 0
                ? (data.position.inMilliseconds / _cachedDurMs).clamp(0.0, 1.0)
                : 0.0);

        // Vị trí hiển thị cho label thời gian
        final displayPos = _dragValue != null
            ? Duration(milliseconds: (_dragValue! * _cachedDurMs).toInt())
            : data.position;
        final c = context.appColors;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                  trackHeight: 3,
                  thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: progress.toDouble(),
                  // Bắt đầu kéo → freeze stream, chỉ update local value
                  onChangeStart: (v) => setState(() => _dragValue = v),
                  // Đang kéo → cập nhật local value ngay lập tức (mượt)
                  onChanged: (v) => setState(() => _dragValue = v),
                  // Nhả tay → seek thật, rồi xóa local value
                  onChangeEnd: (v) async {
                    if (_cachedDurMs > 0) {
                      await widget.player.seekTo(
                        Duration(milliseconds: (v * _cachedDurMs).toInt()),
                      );
                    }
                    // Delay nhỏ để chờ stream cập nhật vị trí mới
                    // trước khi trả quyền điều khiển lại cho stream
                    await Future.delayed(const Duration(milliseconds: 100));
                    if (mounted) setState(() => _dragValue = null);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(displayPos),
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: c.onPlayerLow)),
                    Text(_fmt(data.duration),
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: c.onPlayerLow)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Controls ──────────────────────────────────────────────────────────────────

class _ControlsSection extends StatelessWidget {
  const _ControlsSection({required this.player});
  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _IconBtn(
            icon: Icons.shuffle_rounded,
            color: player.shuffleEnabled
                ? c.primary
                : c.onPlayerLow,
            size: 24,
            onTap: () {
              player.toggleShuffle();
              HapticFeedback.selectionClick();
            },
          ),
          _IconBtn(
            icon: Icons.skip_previous_rounded,
            color: Colors.white,
            size: 36,
            onTap: () {
              player.skipToPrevious();
              HapticFeedback.selectionClick();
            },
          ),
          _PlayButton(player: player),
          _IconBtn(
            icon: Icons.skip_next_rounded,
            color: Colors.white,
            size: 36,
            onTap: () {
              player.skipToNext();
              HapticFeedback.selectionClick();
            },
          ),
          _IconBtn(
            icon: player.repeatMode == RepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: player.repeatMode == RepeatMode.one ? c.primary : c.onPlayerLow,
            size: 24,
            onTap: () {
              player.toggleRepeat();
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.player});
  final PlayerProvider player;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) async {
        await _ctrl.reverse();
        widget.player.playPause();
        HapticFeedback.mediumImpact();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.white.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              widget.player.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              key: ValueKey(widget.player.isPlaying),
              color: c.background,
              size: 38,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) async {
        await _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(widget.icon, color: widget.color, size: widget.size),
        ),
      ),
    );
  }
}

// ── Extra actions ─────────────────────────────────────────────────────────────

class _ExtraActions extends StatelessWidget {
  const _ExtraActions({
    required this.player,
    required this.onQueueTap,
    required this.queueVisible,
  });
  final PlayerProvider player;
  final VoidCallback onQueueTap;
  final bool queueVisible;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _IconBtn(
            icon: Icons.volume_up_rounded,
            color: c.onPlayerSubtle,
            size: 22,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Dùng nút âm lượng vật lý để điều chỉnh',
                      style: GoogleFonts.outfit(fontSize: 13)),
                  duration: const Duration(seconds: 2),
                  backgroundColor: c.surfaceElevated,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
          _IconBtn(
            icon: Icons.share_rounded,
            color: Colors.white38,
            size: 22,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                  Text('Chia sẻ: ${player.currentSong?.title ?? ""}'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: c.surfaceElevated,
                ),
              );
            },
          ),
          GestureDetector(
            onTap: onQueueTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: queueVisible
                    ? c.primary.withOpacity(0.25)
                    : c.onPlayerGhostBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: queueVisible
                      ? c.primary.withOpacity(0.5)
                      : c.onPlayerGhost,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.queue_music_rounded,
                      color:
                      queueVisible ? c.primary : Colors.white54,
                      size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Hàng chờ (${player.queue.length})',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: queueVisible
                            ? c.primary
                            : Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Queue sheet ───────────────────────────────────────────────────────────────

class _QueueSheet extends StatelessWidget {
  const _QueueSheet({
    required this.player,
    required this.onClose,
    required this.useBlur,
  });
  final PlayerProvider player;
  final VoidCallback onClose;
  final bool useBlur;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final sheetContent = Container(
      decoration: BoxDecoration(
        // Solid base color luôn có — tránh flickering
        color: c.surface.withOpacity(useBlur ? 0.75 : 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
            top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hàng chờ phát',
                          style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary)),
                      Text('${player.queue.length} bài hát',
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: c.textTertiary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: c.textTertiary, size: 26),
                ),
              ],
            ),
          ),
          Divider(color: c.divider, height: 1),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: player.queue.length,
              onReorder: player.reorderQueue,
              itemBuilder: (_, i) {
                final song = player.queue[i];
                final isActive = player.currentSong?.id == song.id;
                return ListTile(
                  key: ValueKey(song.id),
                  tileColor: isActive
                      ? c.primary.withOpacity(0.08)
                      : null,
                  leading: SizedBox(
                    width: 40,
                    height: 40,
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
                          child: Icon(Icons.music_note_rounded,
                              color: c.textDisabled, size: 18),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive
                          ? c.primary
                          : c.textPrimary,
                      fontSize: 14,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(song.artist,
                      maxLines: 1,
                      style: TextStyle(
                          color: c.textTertiary, fontSize: 12)),
                  trailing: isActive
                      ? Icon(Icons.equalizer_rounded,
                      color: c.primary, size: 20)
                      : GestureDetector(
                    onTap: () => player.removeFromQueue(i),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded,
                          color: c.textDisabled, size: 18),
                    ),
                  ),
                  onTap: () => player.skipToIndex(i),
                );
              },
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: useBlur
          ? BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: sheetContent,
      )
          : sheetContent,
    );
  }
}