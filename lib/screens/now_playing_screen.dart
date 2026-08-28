import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:provider/provider.dart';
import '../features/music_visual/widgets/reactive_waveform_view.dart';
import '../providers/lyrics_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/now_playing/album_art_section.dart';
import '../widgets/now_playing/controls.dart';
import '../widgets/now_playing/expandable_pill_bar.dart';
import '../widgets/now_playing/lyrics_view.dart';
import '../widgets/now_playing/sheets/queue_sheet.dart';
import '../widgets/now_playing/song_info.dart';
import '../widgets/now_playing/swipe_hint.dart';
import '../widgets/now_playing/top_bar.dart';

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
    _flipAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOutCubic));

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
            tooltip: 'Đóng',
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
            Positioned.fill(child: BlurredBackground(albumId: song.albumId)),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _appearCtrl,
                  curve: Curves.easeOut,
                ),
                child: Column(
                  children: [
                    TopBar(song: song),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Column(
                        children: [
                          // ── Flip card: Album art ↔ Lyrics ───────────────
                          FlipCard(
                            flipAnim: _flipAnim,
                            front: AlbumArtSection(
                              song: song,
                              player: player,
                              rotateCtrl: _artRotateCtrl,
                              onTap: _toggleFlip,
                            ),
                            back: LyricsView(
                              lyricsProvider: lyricsProvider,
                              player: player,
                              scrollCtrl: _lyricsScrollCtrl,
                              onScrollToLine: _scrollToCurrentLine,
                              onTap: _toggleFlip,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SongInfo(song: song),
                          const SizedBox(height: 20),
                          ProgressSection(player: player),
                          const ReactiveWaveformView(),
                          const SizedBox(height: 20),
                          ControlsSection(player: player),
                          const SizedBox(height: 16),
                          ExpandablePillBar(
                            player: player,
                            lyricsProvider: lyricsProvider,
                            onQueueTap: () {
                              if (_queueVisible) {
                                _closeQueue();
                              } else {
                                _openQueue();
                              }
                            },
                            onLyricsTap: _toggleFlip,
                            showingLyrics: _showingLyrics,
                            queueVisible: _queueVisible,
                          ),
                          const SizedBox(height: 20),
                          if (!_queueVisible) SwipeHint(onTap: _openQueue),
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
              bottom:
                  _queueVisible ? 0 : -MediaQuery.of(context).size.height * 0.6,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.6,
              child: RepaintBoundary(
                child: QueueSheet(
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
