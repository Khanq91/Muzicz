import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/utils/duration_format.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../services/audio_handler.dart';

class ControlsSection extends StatelessWidget {
  const ControlsSection({super.key, required this.player});
  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // `player` is only used for actions; the rendered bits are selected so
    // this row rebuilds on shuffle/repeat changes, not on every notify.
    final (shuffleEnabled, repeatMode) = context
        .select<PlayerProvider, (bool, RepeatMode)>(
          (p) => (p.shuffleEnabled, p.repeatMode),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconBtn(
            icon: Icons.shuffle_rounded,
            label: 'Phát ngẫu nhiên',
            toggled: shuffleEnabled,
            color: shuffleEnabled ? c.primary : c.onPlayerLow,
            size: 24,
            onTap: () {
              player.toggleShuffle();
              HapticFeedback.selectionClick();
            },
          ),
          IconBtn(
            icon: Icons.skip_previous_rounded,
            label: 'Bài trước',
            color: Colors.white,
            size: 36,
            onTap: () {
              player.skipToPrevious();
              HapticFeedback.selectionClick();
            },
          ),
          PlayButton(player: player),
          IconBtn(
            icon: Icons.skip_next_rounded,
            label: 'Bài tiếp theo',
            color: Colors.white,
            size: 36,
            onTap: () {
              player.skipToNext();
              HapticFeedback.selectionClick();
            },
          ),
          IconBtn(
            icon:
                repeatMode == RepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
            label: repeatMode == RepeatMode.one ? 'Lặp lại một bài' : 'Lặp lại',
            toggled: repeatMode != RepeatMode.none,
            color: repeatMode == RepeatMode.one ? c.primary : c.onPlayerLow,
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

class PlayButton extends StatefulWidget {
  const PlayButton({super.key, required this.player});
  final PlayerProvider player;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    return Semantics(
      button: true,
      label: isPlaying ? 'Tạm dừng' : 'Phát',
      child: GestureDetector(
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
                  color: Colors.white.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder:
                  (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(isPlaying),
                color: c.background,
                size: 38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class IconBtn extends StatefulWidget {
  const IconBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.size,
    required this.onTap,
    this.toggled,
  });
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final bool? toggled;

  @override
  State<IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<IconBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      toggled: widget.toggled,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) async {
          await _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scale,
          child: SizedBox(
            width: widget.size + 16 < 48 ? 48 : widget.size + 16,
            height: widget.size + 16 < 48 ? 48 : widget.size + 16,
            child: Center(
              child: Icon(widget.icon, color: widget.color, size: widget.size),
            ),
          ),
        ),
      ),
    );
  }
}

class ProgressSection extends StatefulWidget {
  const ProgressSection({super.key, required this.player});
  final PlayerProvider player;

  @override
  State<ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<ProgressSection> {
  double? _dragValue;
  int _cachedDurMs = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PositionData>(
      stream: widget.player.positionDataStream,
      builder: (_, snap) {
        final data =
            snap.data ??
            const PositionData(Duration.zero, Duration.zero, Duration.zero);
        final durMs = data.duration.inMilliseconds;
        if (durMs > 0) _cachedDurMs = durMs;
        final progress =
            _dragValue ??
            (_cachedDurMs > 0
                ? (data.position.inMilliseconds / _cachedDurMs).clamp(0.0, 1.0)
                : 0.0);
        final displayPos =
            _dragValue != null
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
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                ),
                child: Slider(
                  value: progress.toDouble(),
                  onChangeStart: (v) => setState(() => _dragValue = v),
                  onChanged: (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) async {
                    if (_cachedDurMs > 0) {
                      await widget.player.seekTo(
                        Duration(milliseconds: (v * _cachedDurMs).toInt()),
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
                    Text(
                      displayPos.mmss,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: c.onPlayerLow,
                      ),
                    ),
                    Text(
                      data.duration.mmss,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: c.onPlayerLow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
