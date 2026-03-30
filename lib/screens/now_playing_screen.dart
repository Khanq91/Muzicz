import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_item.dart';
import '../providers/music_provider.dart';
import '../providers/player_provider.dart';
import '../services/audio_handler.dart';
import '../theme/app_colors.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _artRotateCtrl;
  bool _queueVisible = false;

  @override
  void initState() {
    super.initState();
    _artRotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
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
    context.read<PlayerProvider>().removeListener(_onPlayerChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;

    if (song == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
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
      },
      onHorizontalDragEnd: (d) {
        if (d.primaryVelocity == null) return;
        if (d.primaryVelocity! < -300) player.skipToNext();
        if (d.primaryVelocity! > 300) player.skipToPrevious();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Blurred background
            Positioned.fill(
              child: _BlurredBackground(albumId: song.albumId),
            ),
            // Dark overlay
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.55)),
            ),
            // Content
            SafeArea(
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
                          onQueueTap: () =>
                              setState(() => _queueVisible = !_queueVisible),
                          queueVisible: _queueVisible,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Queue sheet
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              bottom: _queueVisible
                  ? 0
                  : -MediaQuery.of(context).size.height * 0.6,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.6,
              child: _QueueSheet(
                player: player,
                onClose: () => setState(() => _queueVisible = false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Blurred background ────────────────────────────────────

class _BlurredBackground extends StatelessWidget {
  const _BlurredBackground({required this.albumId});
  final int albumId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient fallback
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
        ),
        // Album art blurred
        QueryArtworkWidget(
          id: albumId,
          type: ArtworkType.ALBUM,
          artworkFit: BoxFit.cover,
          artworkBorder: BorderRadius.zero,
          keepOldArtwork: true,
          nullArtworkWidget: const SizedBox.shrink(),
        ),
        // Blur layer on top
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }
}

// ── Top bar ───────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.song});
  final SongItem song;

  @override
  Widget build(BuildContext context) {
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
                Text(
                  'Từ thư viện',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // 3-dot menu: working
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                size: 24, color: Colors.white),
            color: AppColors.card,
            onSelected: (val) {
              switch (val) {
                case 'info':
                  _showSongInfo(context, song);
                  break;
                case 'playlist':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thêm vào playlist')),
                  );
                  break;
                case 'fav':
                  context.read<MusicProvider>().toggleFavorite(song.id);
                  break;
              }
            },
            itemBuilder: (_) => [
              _popItem('fav', Icons.favorite_border_rounded, 'Yêu thích'),
              _popItem('playlist', Icons.playlist_add_rounded,
                  'Thêm vào playlist'),
              _popItem('info', Icons.info_outline_rounded, 'Thông tin bài hát'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _popItem(String val, IconData icon, String label) {
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.outfit(
                  color: AppColors.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }

  void _showSongInfo(BuildContext context, SongItem song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
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
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _infoRow('Tên bài', song.title),
            _infoRow('Nghệ sĩ', song.artist),
            _infoRow('Album', song.album),
            _infoRow('Thời lượng', song.durationFormatted),
            // if (song.year != null) _infoRow('Năm', '${song.year}'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: GoogleFonts.outfit(
                    color: AppColors.textTertiary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── Album art ─────────────────────────────────────────────

class _AlbumArtSection extends StatelessWidget {
  const _AlbumArtSection(
      {required this.song, required this.rotateCtrl});
  final SongItem song;
  final AnimationController rotateCtrl;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.70;

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
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
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
                    const BoxDecoration(gradient: AppColors.primaryGradient),
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

// ── Song info + favorite ──────────────────────────────────

class _SongInfo extends StatelessWidget {
  const _SongInfo({required this.song});
  final SongItem song;

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final isFav = music.isFavorite(song.id);

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
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => music.toggleFavorite(song.id),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isFav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey(isFav),
                color: isFav ? AppColors.tertiary : Colors.white54,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress ──────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.player});
  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PositionData>(
      stream: player.positionDataStream,
      builder: (_, snap) {
        final data = snap.data ??
            const PositionData(Duration.zero, Duration.zero, Duration.zero);
        final dur = data.duration.inMilliseconds;
        final pos = data.position.inMilliseconds;
        final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

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
                  onChanged: (v) {
                    if (dur > 0) {
                      player.seekTo(
                          Duration(milliseconds: (v * dur).toInt()));
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(data.position),
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: Colors.white54)),
                    Text(_fmt(data.duration),
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: Colors.white54)),
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

// ── Controls ──────────────────────────────────────────────

class _ControlsSection extends StatelessWidget {
  const _ControlsSection({required this.player});
  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle
          _IconBtn(
            icon: Icons.shuffle_rounded,
            color: player.shuffleEnabled
                ? AppColors.primary
                : Colors.white54,
            size: 24,
            badge: null,
            onTap: player.toggleShuffle,
          ),
          // Prev
          _IconBtn(
            icon: Icons.skip_previous_rounded,
            color: Colors.white,
            size: 36,
            badge: null,
            onTap: player.skipToPrevious,
          ),
          // Play/Pause
          _PlayButton(player: player),
          // Next
          _IconBtn(
            icon: Icons.skip_next_rounded,
            color: Colors.white,
            size: 36,
            badge: null,
            onTap: player.skipToNext,
          ),
          // Repeat — shows badge "1" only when RepeatMode.one
          _IconBtn(
            icon: player.repeatMode == RepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: player.repeatMode != RepeatMode.none
                ? AppColors.primary
                : Colors.white54,
            size: 24,
            badge: null,
            onTap: player.toggleRepeat,
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
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) async {
        await _ctrl.reverse();
        widget.player.playPause();
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
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            widget.player.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            color: AppColors.background,
            size: 38,
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
    this.badge,
  });
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final String? badge;

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

// ── Extra actions ─────────────────────────────────────────

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Volume — opens system volume panel
          _IconBtn(
            icon: Icons.volume_up_rounded,
            color: Colors.white54,
            size: 22,
            badge: null,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dùng nút âm lượng vật lý để điều chỉnh'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          // Share
          _IconBtn(
            icon: Icons.share_rounded,
            color: Colors.white54,
            size: 22,
            badge: null,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Chia sẻ: ${player.currentSong?.title ?? ""}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          // Queue button
          GestureDetector(
            onTap: onQueueTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: queueVisible
                    ? AppColors.primary.withOpacity(0.25)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: queueVisible
                      ? AppColors.primary.withOpacity(0.5)
                      : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.queue_music_rounded,
                      color: queueVisible
                          ? AppColors.primary
                          : Colors.white54,
                      size: 18),
                  const SizedBox(width: 6),
                  Text('Hàng chờ',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: queueVisible
                              ? AppColors.primary
                              : Colors.white54)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Queue sheet ───────────────────────────────────────────

class _QueueSheet extends StatelessWidget {
  const _QueueSheet({required this.player, required this.onClose});
  final PlayerProvider player;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.92),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: const Border(
                top: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hàng chờ (${player.queue.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textTertiary, size: 20),
                    ),
                  ],
                ),
              ),
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
                              color: AppColors.surfaceElevated,
                              child: const Icon(Icons.music_note_rounded,
                                  color: AppColors.textDisabled, size: 18),
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
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      subtitle: Text(song.artist,
                          maxLines: 1,
                          style: const TextStyle(
                              color: AppColors.textTertiary, fontSize: 12)),
                      trailing: GestureDetector(
                        onTap: () => player.removeFromQueue(i),
                        child: const Icon(Icons.close_rounded,
                            color: AppColors.textDisabled, size: 18),
                      ),
                      onTap: () => player.skipToIndex(i),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
