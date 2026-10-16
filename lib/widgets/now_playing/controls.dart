import 'dart:async';
import 'package:flutter/physics.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muziczz/theme/app_colors_data.dart';
import 'package:muziczz/utils/duration_format.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../services/audio_handler.dart';
import 'package:muziczz/core/app_strings.dart';

import '../../providers/music_provider.dart';
import 'wavy_seek_bar.dart';

/// PixelPlayer transport motion: expand the chosen button, compress its
/// neighbours, then spring the row back. Only this row rebuilds per frame.
class ControlsSection extends StatefulWidget {
  const ControlsSection({super.key, required this.player});
  final PlayerProvider player;
  @override
  State<ControlsSection> createState() => _ControlsSectionState();
}

class _ControlsSectionState extends State<ControlsSection>
    with TickerProviderStateMixin {
  late final AnimationController _motion;
  late final AnimationController _playIcon;
  List<double> _from = [1, 1, 1];
  List<double> _to = [1, 1, 1];
  Timer? _release;
  final Set<Timer> _actions = {};
  @override
  void initState() {
    super.initState();
    _motion = AnimationController.unbounded(vsync: this, value: 1);
    _playIcon = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: widget.player.isPlaying ? 1 : 0,
    );
    widget.player.addListener(_syncIcon);
  }

  void _syncIcon() {
    final target = widget.player.isPlaying ? 1.0 : 0.0;
    if (_playIcon.value != target) {
      _playIcon.animateTo(target, curve: Curves.easeOutCubic);
    }
  }

  List<double> get _weights => List.generate(
    3,
    (i) => (_from[i] + (_to[i] - _from[i]) * _motion.value).clamp(.4, 1.4),
  );
  void _animate(List<double> target) {
    _from = _weights;
    _to = target;
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
      return;
    }
    _motion.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 450, damping: 28),
        0,
        1,
        0,
      ),
    );
  }

  void _press(int index) {
    HapticFeedback.selectionClick();
    _release?.cancel();
    _animate(List.generate(3, (i) => i == index ? 1.1 : .65));
    _release = Timer(Duration(milliseconds: index == 1 ? 220 : 600), () {
      if (mounted) _animate([1, 1, 1]);
    });
    if (index == 1) {
      widget.player.playPause();
      return;
    }
    late final Timer action;
    action = Timer(const Duration(milliseconds: 180), () {
      _actions.remove(action);
      if (!mounted) return;
      if (index == 0) {
        widget.player.skipToPrevious();
      } else {
        widget.player.skipToNext();
      }
    });
    _actions.add(action);
  }

  @override
  void dispose() {
    widget.player.removeListener(_syncIcon);
    _release?.cancel();
    for (final action in _actions) {
      action.cancel();
    }
    _motion.dispose();
    _playIcon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final playing = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: AnimatedBuilder(
        animation: _motion,
        builder: (_, _) {
          final weights = _weights;
          return Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  flex: (weights[i] * 1000).round(),
                  child: SizedBox(
                    key: ValueKey('transport-$i'),
                    height: 80,
                    child: AnimatedContainer(
                      duration:
                          MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      decoration: BoxDecoration(
                        color:
                            i == 1
                                ? Color.lerp(c.tertiary, c.surface, .45)
                                : c.primary,
                        borderRadius: BorderRadius.circular(
                          i == 1 && playing ? 26 : 60,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            i == 1 && playing ? 26 : 60,
                          ),
                          onTap: () => _press(i),
                          child: Semantics(
                            button: true,
                            label:
                                i == 0
                                    ? AppStrings.previousTrack
                                    : i == 2
                                    ? AppStrings.nextTrack
                                    : playing
                                    ? AppStrings.pause
                                    : AppStrings.play,
                            child: Center(
                              child:
                                  i == 1
                                      ? AnimatedIcon(
                                        icon: AnimatedIcons.play_pause,
                                        progress: _playIcon,
                                        size: 34,
                                        color: c.textPrimary,
                                      )
                                      : Icon(
                                        i == 0
                                            ? Icons.skip_previous_rounded
                                            : Icons.skip_next_rounded,
                                        size: 32,
                                        color: Colors.white,
                                      ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class PlayerToggleRow extends StatelessWidget {
  const PlayerToggleRow({super.key, required this.player});
  final PlayerProvider player;
  @override
  Widget build(BuildContext context) {
    final (shuffle, repeat, songId) = context
        .select<PlayerProvider, (bool, RepeatMode, int?)>(
          (p) => (p.shuffleEnabled, p.repeatMode, p.currentSong?.id),
        );
    final favorite = context.select<MusicProvider, bool>(
      (m) => songId != null && m.isFavorite(songId),
    );
    final c = context.appColors;
    final icons = [
      Icons.shuffle_rounded,
      repeat == RepeatMode.one
          ? Icons.repeat_one_rounded
          : Icons.repeat_rounded,
      favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
    ];
    final labels = [
      AppStrings.shufflePlay,
      repeat == RepeatMode.one ? AppStrings.repeatOne : AppStrings.repeat,
      favorite ? AppStrings.unfavorite : AppStrings.favorites,
    ];
    final active = [shuffle, repeat != RepeatMode.none, favorite];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: c.background.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
                  child: AnimatedContainer(
                    duration:
                        MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    decoration: BoxDecoration(
                      color:
                          active[i]
                              ? c.primary.withValues(alpha: .24)
                              : c.surfaceElevated,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(i == 0 ? 36 : 9),
                        right: Radius.circular(i == 2 ? 36 : 9),
                      ),
                    ),
                    child: MergeSemantics(
                      child: Semantics(
                        label: labels[i],
                        toggled: active[i],
                        child: IconButton(
                          tooltip: labels[i],
                          constraints: const BoxConstraints(minHeight: 54),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            if (i == 0) {
                              player.toggleShuffle();
                            }
                            if (i == 1) {
                              player.toggleRepeat();
                            }
                            if (i == 2 && songId != null) {
                              context.read<MusicProvider>().toggleFavorite(
                                songId,
                              );
                            }
                          },
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder:
                                (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              icons[i],
                              key: ValueKey((icons[i], active[i])),
                              size: 25,
                              color: active[i] ? c.primary : c.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
  String _fileType(String path) {
    final extension = path.split('.').last.toUpperCase();
    return extension.length <= 5 ? extension : 'AUDIO';
  }

  double? _dragValue;
  int _cachedDurMs = 0;

  @override
  Widget build(BuildContext context) {
    final playing = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    return StreamBuilder<PositionData>(
      stream:
          TickerMode.valuesOf(context).enabled
              ? widget.player.positionDataStream
              : null,
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
              WavySeekBar(
                value: progress.toDouble(),
                playing: playing,
                onChangeStart: (v) => setState(() => _dragValue = v),
                onChanged: (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) async {
                  if (_cachedDurMs > 0) {
                    await widget.player.seekTo(
                      Duration(milliseconds: (v * _cachedDurMs).toInt()),
                    );
                  }
                  if (mounted) setState(() => _dragValue = null);
                },
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
                        color: c.playerMuted,
                      ),
                    ),
                    Flexible(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _fileType(widget.player.currentSong?.data ?? ''),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      Duration(milliseconds: _cachedDurMs).mmss,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: c.playerMuted,
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
