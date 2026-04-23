import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../models/song_item.dart';
import '../providers/lyrics_provider.dart';
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

  // ── Flip animation ─────────────────────────────────────────────────────────
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;
  bool _showingLyrics = false;

  bool _queueVisible = false;
  bool _queueFullyOpen = false;
  late final PlayerProvider _playerProvider;

  // ── Lyrics auto-scroll ─────────────────────────────────────────────────────
  final _lyricsScrollCtrl = ScrollController();
  static const _lineHeight = 52.0; // approx height per line for scroll calc

  @override
  void initState() {
    super.initState();

    _playerProvider = context.read<PlayerProvider>();

    _artRotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    _appearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOutCubic),
    );

    if (_playerProvider.isPlaying) _artRotateCtrl.repeat();
    _playerProvider.addListener(_onPlayerChange);

    // Preload lyrics cho bài hiện tại
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final song = _playerProvider.currentSong;
      if (song != null) {
        context.read<LyricsProvider>().loadLyrics(song);
      }
    });
  }

  void _onPlayerChange() {
    if (_playerProvider.isPlaying) {
      if (!_artRotateCtrl.isAnimating) _artRotateCtrl.repeat();
    } else {
      _artRotateCtrl.stop();
    }

    // Khi bài đổi → load lyrics mới + reset flip về album art
    final song = _playerProvider.currentSong;
    if (song != null) {
      final lyricsProvider = context.read<LyricsProvider>();
      if (lyricsProvider.state.songId != song.id) {
        lyricsProvider.loadLyrics(song);
        if (_showingLyrics) _flipBack();
      }
    }
  }

  @override
  void dispose() {
    _artRotateCtrl.dispose();
    _appearCtrl.dispose();
    _flipCtrl.dispose();
    _lyricsScrollCtrl.dispose();
    _playerProvider.removeListener(_onPlayerChange);
    super.dispose();
  }

  // ── Flip logic ─────────────────────────────────────────────────────────────

  void _flipToLyrics() {
    setState(() => _showingLyrics = true);
    _flipCtrl.forward();
    HapticFeedback.lightImpact();
  }

  void _flipBack() {
    _flipCtrl.reverse().then((_) {
      if (mounted) setState(() => _showingLyrics = false);
    });
  }

  void _toggleFlip() {
    if (_showingLyrics) {
      _flipBack();
    } else {
      _flipToLyrics();
    }
  }

  // ── Queue ──────────────────────────────────────────────────────────────────

  void _openQueue() {
    setState(() {
      _queueVisible = true;
      _queueFullyOpen = false;
    });
    HapticFeedback.lightImpact();
  }

  void _closeQueue() {
    setState(() {
      _queueVisible = false;
      _queueFullyOpen = false;
    });
  }

  // ── Auto-scroll lyrics ─────────────────────────────────────────────────────

  void _scrollToCurrentLine(int index) {
    if (!_lyricsScrollCtrl.hasClients) return;
    if (index < 0) return;

    final viewportHeight = _lyricsScrollCtrl.position.viewportDimension;
    final targetOffset =
        (index * _lineHeight) - (viewportHeight / 2) + (_lineHeight / 2);
    final clampedOffset = targetOffset.clamp(
      0.0,
      _lyricsScrollCtrl.position.maxScrollExtent,
    );

    _lyricsScrollCtrl.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
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

    // Sync lyrics position
    final lyricsProvider = context.watch<LyricsProvider>();

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 400) Navigator.pop(context);
        if ((d.primaryVelocity ?? 0) < -400 && !_queueVisible) _openQueue();
      },
      onHorizontalDragEnd: (d) {
        // Không xử lý horizontal swipe sẽ conflict với lyrics scroll
        if (_showingLyrics) return;
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
              child: Container(color: Colors.black.withOpacity(0.55)),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: CurvedAnimation(
                    parent: _appearCtrl, curve: Curves.easeOut),
                child: Column(
                  children: [
                    _TopBar(song: song),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Column(
                        children: [
                          // ── Flip card: Album art ↔ Lyrics ───────────────
                          _FlipCard(
                            flipAnim: _flipAnim,
                            front: _AlbumArtSection(
                              song: song,
                              rotateCtrl: _artRotateCtrl,
                              onTap: _toggleFlip,
                            ),
                            back: _LyricsView(
                              lyricsProvider: lyricsProvider,
                              player: player,
                              scrollCtrl: _lyricsScrollCtrl,
                              onScrollToLine: _scrollToCurrentLine,
                              onTap: _toggleFlip,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _SongInfo(song: song),
                          const SizedBox(height: 20),
                          _ProgressSection(player: player),
                          const SizedBox(height: 20),
                          _ControlsSection(player: player),
                          const SizedBox(height: 16),
                          _ExpandablePillBar(
                            player: player,
                            lyricsProvider: lyricsProvider,
                            onQueueTap: () {
                              if (_queueVisible) _closeQueue();
                              else _openQueue();
                            },
                            onLyricsTap: _toggleFlip,
                            showingLyrics: _showingLyrics,
                            queueVisible: _queueVisible,
                          ),
                          const SizedBox(height: 20),
                          if (!_queueVisible)
                            _SwipeHint(onTap: _openQueue),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              onEnd: () {
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

// ════════════════════════════════════════════════════════════════════════════
// _FlipCard — 3D flip animation between front and back
// ════════════════════════════════════════════════════════════════════════════

class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.flipAnim,
    required this.front,
    required this.back,
  });

  final Animation<double> flipAnim;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flipAnim,
      builder: (context, child) {
        final angle = flipAnim.value * pi;
        final showBack = flipAnim.value >= 0.5;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(angle),
          child: showBack
              ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(pi),
            child: back,
          )
              : front,
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _LyricsView
// ════════════════════════════════════════════════════════════════════════════

class _LyricsView extends StatefulWidget {
  const _LyricsView({
    required this.lyricsProvider,
    required this.player,
    required this.scrollCtrl,
    required this.onScrollToLine,
    required this.onTap,
  });

  final LyricsProvider lyricsProvider;
  final PlayerProvider player;
  final ScrollController scrollCtrl;
  final void Function(int index) onScrollToLine;
  final VoidCallback onTap;

  @override
  State<_LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<_LyricsView> {
  int _lastScrolledIndex = -1;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.70;
    final c = context.appColors;
    final lp = widget.lyricsProvider;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              shape: BoxShape.circle,
            ),
            child: _buildContent(context, lp, c, size),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext ctx, LyricsProvider lp, AppColorsData c, double size) {
    // Loading
    if (lp.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Đang tải lời bài hát…',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      );
    }

    // Not found / error
    if (lp.status == LyricsStatus.notFound ||
        lp.status == LyricsStatus.error ||
        lp.status == LyricsStatus.idle) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              lp.status == LyricsStatus.error
                  ? Icons.wifi_off_rounded
                  : Icons.lyrics_rounded,
              color: Colors.white30,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              lp.status == LyricsStatus.error
                  ? 'Không thể tải lời bài hát'
                  : 'Không có lời bài hát',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      );
    }

    // Has lyrics — synced or plain
    return _LyricsListView(
      lyricsProvider: lp,
      player: widget.player,
      scrollCtrl: widget.scrollCtrl,
      onScrollToLine: (index) {
        if (index != _lastScrolledIndex) {
          _lastScrolledIndex = index;
          widget.onScrollToLine(index);
        }
      },
      circleSize: size,
    );
  }
}

// ── Lyrics list với position sync ────────────────────────────────────────────

class _LyricsListView extends StatelessWidget {
  const _LyricsListView({
    required this.lyricsProvider,
    required this.player,
    required this.scrollCtrl,
    required this.onScrollToLine,
    required this.circleSize,
  });

  final LyricsProvider lyricsProvider;
  final PlayerProvider player;
  final ScrollController scrollCtrl;
  final void Function(int) onScrollToLine;
  final double circleSize;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    if (lyricsProvider.isSynced) {
      return StreamBuilder<PositionData>(
        stream: player.positionDataStream,
        builder: (context, snap) {
          if (snap.hasData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              lyricsProvider.updatePosition(snap.data!.position);
              onScrollToLine(lyricsProvider.currentIndex);
            });
          }
          return _buildList(context, c);
        },
      );
    }

    return _buildList(context, c);
  }

  Widget _buildList(BuildContext context, AppColorsData c) {
    final lines = lyricsProvider.lines;
    final currentIdx = lyricsProvider.currentIndex;
    final padding = circleSize * 0.18;

    return ListView.builder(
      controller: scrollCtrl,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: circleSize * 0.25,
      ),
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final line = lines[i];
        final isActive = lyricsProvider.isSynced && i == currentIdx;
        final isPast = lyricsProvider.isSynced && i < currentIdx;

        // Dòng trống = instrumental break
        if (line.text.isEmpty) {
          return SizedBox(
            height: 28,
            child: isActive
                ? Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                      (i) => Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? c.primary
                          : Colors.white24,
                    ),
                  ),
                ),
              ),
            )
                : const SizedBox.shrink(),
          );
        }

        return AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          style: GoogleFonts.outfit(
            fontSize: isActive ? 15 : 13,
            fontWeight:
            isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive
                ? Colors.white
                : isPast
                ? Colors.white38
                : Colors.white60,
            height: 1.5,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              line.text,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _AlbumArtSection — now tappable
// ════════════════════════════════════════════════════════════════════════════

class _AlbumArtSection extends StatelessWidget {
  const _AlbumArtSection({
    required this.song,
    required this.rotateCtrl,
    required this.onTap,
  });

  final SongItem song;
  final AnimationController rotateCtrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.70;
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Center(
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
                  decoration: BoxDecoration(gradient: c.primaryGradient),
                  child: const Icon(Icons.music_note_rounded,
                      color: Colors.white54, size: 80),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _ExtraActions — thêm lyrics button
// ════════════════════════════════════════════════════════════════════════════

class _ExpandablePillBar extends StatefulWidget {
  const _ExpandablePillBar({
    required this.player,
    required this.lyricsProvider,
    required this.onQueueTap,
    required this.onLyricsTap,
    required this.showingLyrics,
    required this.queueVisible,
  });

  final PlayerProvider player;
  final LyricsProvider lyricsProvider;
  final VoidCallback onQueueTap;
  final VoidCallback onLyricsTap;
  final bool showingLyrics;
  final bool queueVisible;

  @override
  State<_ExpandablePillBar> createState() => _ExpandablePillBarState();
}

class _ExpandablePillBarState extends State<_ExpandablePillBar> {
  bool _isExpanded = false;

  void _showSpeedSheet(BuildContext context, PlayerProvider player) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: player,
        child: const _SpeedSheet(),
      ),
    );
  }

  void _showSleepTimerSheet(BuildContext context, PlayerProvider player) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: player,
        child: const _SleepTimerSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    final lyricsActive = widget.showingLyrics;
    final queueActive = widget.queueVisible;
    final speedActive = widget.player.speed != 1.0;
    final timerActive = widget.player.sleepTimerActive;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: 52,
        width: _isExpanded ? 280 : 64,
        decoration: BoxDecoration(
          color: _isExpanded ? c.surfaceElevated.withOpacity(0.9) : c.onPlayerGhostBg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _isExpanded ? c.border.withOpacity(0.3) : c.onPlayerGhost),
          boxShadow: _isExpanded ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          ] : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isExpanded ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _isExpanded,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _isExpanded = true),
                      child: Container(
                        alignment: Alignment.center,
                        child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isExpanded ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isExpanded,
                  child: OverflowBox(
                    maxWidth: 280,
                    minWidth: 280,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionIcon(
                          icon: Icons.lyrics_rounded,
                          isActive: lyricsActive,
                          c: c,
                          onTap: widget.onLyricsTap,
                        ),
                        _buildActionIcon(
                          icon: Icons.queue_music_rounded,
                          isActive: queueActive,
                          c: c,
                          onTap: widget.onQueueTap,
                        ),
                        _buildActionIcon(
                          icon: Icons.speed_rounded,
                          isActive: speedActive,
                          c: c,
                          onTap: () => _showSpeedSheet(context, widget.player),
                        ),
                        _buildActionIcon(
                          icon: Icons.bedtime_rounded,
                          isActive: timerActive,
                          c: c,
                          onTap: () => _showSleepTimerSheet(context, widget.player),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _isExpanded = false),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white12,
                            ),
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  )
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required bool isActive,
    required AppColorsData c,
    required VoidCallback onTap,
  }) {
    return Transform.scale(
      scale: _isExpanded ? 1.0 : 0.8,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? c.primary.withOpacity(0.2) : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? c.primary : Colors.white70,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Các widget không thay đổi so với original — copy nguyên
// ════════════════════════════════════════════════════════════════════════════

// Deleted _SpeedAndTimerRow

class _SpeedSheet extends StatelessWidget {
  const _SpeedSheet();
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: c.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Tốc độ phát',
                  style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
              const Spacer(),
              if (player.speed != 1.0)
                TextButton(
                  onPressed: () {
                    player.setSpeed(1.0);
                    Navigator.pop(context);
                  },
                  child: Text('Đặt lại',
                      style:
                      GoogleFonts.outfit(color: c.primary, fontSize: 14)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _speeds.map((s) {
              final active = player.speed == s;
              return GestureDetector(
                onTap: () {
                  player.setSpeed(s);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 72,
                  height: 48,
                  decoration: BoxDecoration(
                    color: active
                        ? c.primary.withOpacity(0.18)
                        : c.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: active ? c.primary : c.border,
                        width: active ? 1.5 : 0.5),
                  ),
                  child: Center(
                    child: Text(
                      s == 1.0 ? 'Bình thường' : '${s}×',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: s == 1.0 ? 10 : 15,
                        fontWeight:
                        active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? c.primary : c.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SleepTimerSheet extends StatelessWidget {
  const _SleepTimerSheet();
  static const _presets = [
    (label: '5 phút', duration: Duration(minutes: 5)),
    (label: '10 phút', duration: Duration(minutes: 10)),
    (label: '15 phút', duration: Duration(minutes: 15)),
    (label: '30 phút', duration: Duration(minutes: 30)),
    (label: '45 phút', duration: Duration(minutes: 45)),
    (label: '60 phút', duration: Duration(hours: 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final c = context.appColors;
    final rem = player.sleepRemaining;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: c.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Hẹn giờ tắt nhạc',
                  style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
              const Spacer(),
              if (player.sleepTimerActive)
                TextButton(
                  onPressed: () {
                    player.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                  child: Text('Hủy hẹn giờ',
                      style:
                      GoogleFonts.outfit(color: c.tertiary, fontSize: 14)),
                ),
            ],
          ),
          if (rem != null && rem > Duration.zero) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.bedtime_rounded, color: c.primary, size: 20),
                  const SizedBox(width: 10),
                  Text('Dừng sau ',
                      style: GoogleFonts.outfit(
                          color: c.textSecondary, fontSize: 14)),
                  Text(
                    _formatRemaining(rem),
                    style: GoogleFonts.outfit(
                        color: c.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Chọn thời gian',
              style: GoogleFonts.outfit(fontSize: 13, color: c.textTertiary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presets
                .map((p) => GestureDetector(
              onTap: () {
                player.setSleepTimer(p.duration);
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border, width: 0.5),
                ),
                child: Text(p.label,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: c.textPrimary,
                        fontWeight: FontWeight.w500)),
              ),
            ))
                .toList(),
          ),
        ],
      ),
    );
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '$m phút';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

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
              style:
              GoogleFonts.outfit(fontSize: 11, color: c.onPlayerMinimal)),
        ],
      ),
    );
  }
}

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
            decoration: BoxDecoration(gradient: c.backgroundGradient)),
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
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                size: 32, color: c.onPlayer),
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
                    color: c.onPlayerLow,
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
            icon: Icon(Icons.more_vert_rounded, size: 24, color: c.onPlayer),
            color: c.card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              switch (val) {
                case 'edit':
                  _showEditDialog(context, song);
                  break;
                case 'hide':
                  _showHideConfirm(context, song);
                  break;
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
                _popItem(context, 'fav',
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    isFav ? 'Bỏ yêu thích' : 'Yêu thích',
                    iconColor: isFav ? c.tertiary : null),
                _popItem(context, 'playlist',
                    Icons.playlist_add_rounded, 'Thêm vào danh sách phát'),
                _popItem(
                    context, 'edit', Icons.edit_rounded, 'Sửa thông tin'),
                _popItem(context, 'hide', Icons.visibility_off_rounded,
                    'Ẩn khỏi thư viện'),
                _popItem(
                    context, 'share', Icons.share_rounded, 'Chia sẻ'),
                _popItem(context, 'info', Icons.info_outline_rounded,
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
                  color: c.divider, borderRadius: BorderRadius.circular(2)),
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
                        Text(song.album,
                            style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary)),
                        Text('${albumSongs.length} bài hát',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: c.textTertiary)),
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 2),
                    leading: isCurrentSong
                        ? Icon(Icons.equalizer_rounded,
                        color: c.primary, size: 24)
                        : Text('${i + 1}',
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: c.textTertiary,
                            fontWeight: FontWeight.w500)),
                    title: Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: isCurrentSong ? c.primary : c.textPrimary,
                        fontWeight: isCurrentSong
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(s.durationFormatted,
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: c.textTertiary)),
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

  PopupMenuItem<String> _popItem(
      BuildContext context, String val, IconData icon, String label,
      {Color? iconColor}) {
    final c = context.appColors;
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? c.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style:
              GoogleFonts.outfit(color: c.textPrimary, fontSize: 14)),
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
            _infoRow(context, 'Tên bài', song.title),
            _infoRow(context, 'Nghệ sĩ', song.artist),
            _infoRow(context, 'Album', song.album),
            _infoRow(context, 'Thời lượng', song.durationFormatted),
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
                      color: c.textTertiary, fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.outfit(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, SongItem song) {
    final titleCtrl = TextEditingController(text: song.title);
    final artistCtrl = TextEditingController(text: song.artist);
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sửa thông tin',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary)),
            const SizedBox(height: 16),
            _metaField(ctx, 'Tên bài hát', titleCtrl),
            const SizedBox(height: 12),
            _metaField(ctx, 'Nghệ sĩ', artistCtrl),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Hủy',
                            style: GoogleFonts.outfit(
                                color: c.textTertiary)))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: c.primary),
                    onPressed: () {
                      final t = titleCtrl.text.trim();
                      final a = artistCtrl.text.trim();
                      if (t.isNotEmpty) {
                        context.read<MusicProvider>().updateSongMeta(
                            song.id,
                            t.isEmpty ? song.title : t,
                            a.isEmpty ? song.artist : a);
                      }
                      Navigator.pop(ctx);
                    },
                    child: Text('Lưu',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaField(
      BuildContext context, String label, TextEditingController ctrl) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
            GoogleFonts.outfit(fontSize: 12, color: c.textTertiary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: GoogleFonts.outfit(color: c.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: c.surfaceElevated,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.primary, width: 1)),
          ),
        ),
      ],
    );
  }

  void _showHideConfirm(BuildContext context, SongItem song) {
    final c = context.appColors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Ẩn bài hát?',
            style: GoogleFonts.outfit(
                color: c.textPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          '"${song.title}" sẽ bị ẩn khỏi thư viện. File gốc không bị xóa. Có thể quét lại để khôi phục.',
          style: GoogleFonts.outfit(color: c.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy',
                  style: GoogleFonts.outfit(color: c.textTertiary))),
          TextButton(
            onPressed: () {
              context.read<MusicProvider>().hideSongFromLibrary(song);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Ẩn',
                style: GoogleFonts.outfit(
                    color: c.tertiary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

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
                    color: c.onPlayer,
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

class _ProgressSection extends StatefulWidget {
  const _ProgressSection({required this.player});
  final PlayerProvider player;

  @override
  State<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<_ProgressSection> {
  double? _dragValue;
  int _cachedDurMs = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PositionData>(
      stream: widget.player.positionDataStream,
      builder: (_, snap) {
        final data = snap.data ??
            const PositionData(Duration.zero, Duration.zero, Duration.zero);
        final durMs = data.duration.inMilliseconds;
        if (durMs > 0) _cachedDurMs = durMs;
        final progress = _dragValue ??
            (_cachedDurMs > 0
                ? (data.position.inMilliseconds / _cachedDurMs).clamp(0.0, 1.0)
                : 0.0);
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
                  onChangeStart: (v) => setState(() => _dragValue = v),
                  onChanged: (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) async {
                    if (_cachedDurMs > 0) {
                      await widget.player.seekTo(
                        Duration(
                            milliseconds: (v * _cachedDurMs).toInt()),
                      );
                    }
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
            color: player.shuffleEnabled ? c.primary : c.onPlayerLow,
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
            color: player.repeatMode == RepeatMode.one
                ? c.primary
                : c.onPlayerLow,
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
        color: c.surface.withOpacity(useBlur ? 0.75 : 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
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
                              fontSize: 12, color: c.textTertiary)),
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
                  tileColor: isActive ? c.primary.withOpacity(0.08) : null,
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
                      color: isActive ? c.primary : c.textPrimary,
                      fontSize: 14,
                      fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.w400,
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
                      padding: const EdgeInsets.all(4),
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