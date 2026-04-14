import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../services/audio_handler.dart';
import '../theme/app_colors.dart';
import '../screens/now_playing_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;
    if (song == null) return const SizedBox.shrink();
    final c = context.appColors;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => const NowPlayingScreen(),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (_, anim, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
                child: child,
              );
            },
          ),
        );
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -300) {
          player.skipToNext();
          HapticFeedback.selectionClick();
        } else if (details.primaryVelocity! > 300) {
          player.skipToPrevious();
          HapticFeedback.selectionClick();
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        height: 68,
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: c.primary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // ── Progress line at bottom ─────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _MiniProgressBar(player: player),
              ),
              // ── Content ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(
                  left: 14,
                  right: 4,
                  top: 0,
                  bottom: 0,
                ),
                child: Row(
                  children: [
                    _AlbumArt(albumId: song.albumId),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // UX 4: Controls with loading state
                    _MiniControls(player: player),
                    _CloseButton(player: player),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Close button ──────────────────────────────────────────────────────────────

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.player});
  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _confirmStop(context);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 68,
        child: Center(
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surfaceElevated,
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Icon(
              Icons.close_rounded,
              color: c.textDisabled,
              size: 14,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmStop(BuildContext context) {
    if (!context.read<PlayerProvider>().isPlaying) {
      context.read<PlayerProvider>().stopAndClear();
      return;
    }
    final c = context.appColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Dừng phát nhạc?',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Hàng chờ hiện tại sẽ bị xóa.',
          style: TextStyle(color: c.textTertiary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy',
                style: TextStyle(color: c.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PlayerProvider>().stopAndClear();
            },
            child: Text('Dừng',
                style: TextStyle(
                    color: c.tertiary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Album art ─────────────────────────────────────────────────────────────────

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({required this.albumId});
  final int albumId;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: c.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: QueryArtworkWidget(
          id: albumId,
          type: ArtworkType.ALBUM,
          artworkFit: BoxFit.cover,
          artworkBorder: BorderRadius.zero,
          nullArtworkWidget: Icon(
            Icons.music_note_rounded,
            color: c.textDisabled,
            size: 20,
          ),
          keepOldArtwork: true,
        ),
      ),
    );
  }
}

// ── Controls with UX 4: Loading state ────────────────────────────────────────

class _MiniControls extends StatelessWidget {
  const _MiniControls({required this.player});
  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ControlButton(
          icon: Icons.skip_previous_rounded,
          onTap: () {
            player.skipToPrevious();
            HapticFeedback.selectionClick();
          },
          size: 22,
        ),
        const SizedBox(width: 2),
        // UX 4: Show loading spinner when buffering
        _SmartPlayPauseButton(player: player),
        const SizedBox(width: 2),
        _ControlButton(
          icon: Icons.skip_next_rounded,
          onTap: () {
            player.skipToNext();
            HapticFeedback.selectionClick();
          },
          size: 22,
        ),
      ],
    );
  }
}

/// UX 4: Play/Pause that also shows loading state when buffering
class _SmartPlayPauseButton extends StatelessWidget {
  const _SmartPlayPauseButton({required this.player});
  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return StreamBuilder<ProcessingState>(
      stream: player.processingStateStream,
      builder: (context, snap) {
        final processingState = snap.data ?? ProcessingState.idle;
        final isLoading = processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering;

        return GestureDetector(
          onTap: () {
            if (!isLoading) {
              player.playPause();
              HapticFeedback.selectionClick();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isLoading
                  ? c.primary.withOpacity(0.5)
                  : c.primary,
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                player.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                key: ValueKey(player.isPlaying),
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ControlButton extends StatefulWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.size = 24,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(widget.icon,
              color: c.textSecondary, size: widget.size),
        ),
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({required this.player});
  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return StreamBuilder<PositionData>(
      stream: player.positionDataStream,
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!;
        final dur = data.duration.inMilliseconds;
        final pos = data.position.inMilliseconds;
        final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

        return LayoutBuilder(
          builder: (_, constraints) => Container(
            height: 2,
            width: constraints.maxWidth,
            color: c.divider,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: constraints.maxWidth * progress,
                height: 2,
                decoration: BoxDecoration(
                  gradient: c.primaryGradient,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}