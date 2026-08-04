import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/song_item.dart';
import '../../../providers/player_provider.dart';
import '../../../services/audio_handler.dart';
import '../../../theme/app_colors_data.dart';
import '../core/visual_feature_flag.dart';
import '../painters/waveform_painter.dart';
import '../providers/visual_feature_controller.dart';
import '../providers/visual_mode_provider.dart';

class ReactiveWaveformView extends StatelessWidget {
  const ReactiveWaveformView({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kMusicVisualFeatureEnabled) return const SizedBox.shrink();

    final enabled = context.select<VisualModeProvider, bool>(
      (provider) => provider.mode.enablesReactiveVisual,
    );
    if (!enabled) return const SizedBox.shrink();

    final song = context.select<PlayerProvider, SongItem?>(
      (provider) => provider.currentSong,
    );
    if (song == null || song.data.isEmpty) return const SizedBox.shrink();

    return _ActiveWaveformView(
      key: ValueKey(song.id),
      song: song,
      player: context.read<PlayerProvider>(),
    );
  }
}

/// This subtree (and its controller) only exists while the user chose Fancy.
final class _ActiveWaveformView extends StatefulWidget {
  const _ActiveWaveformView({
    super.key,
    required this.song,
    required this.player,
  });

  final SongItem song;
  final PlayerProvider player;

  @override
  State<_ActiveWaveformView> createState() => _ActiveWaveformViewState();
}

final class _ActiveWaveformViewState extends State<_ActiveWaveformView> {
  late final VisualFeatureController _controller;
  late final ValueNotifier<double> _playhead;
  late final StreamSubscription<PositionData> _positionSubscription;

  @override
  void initState() {
    super.initState();
    _playhead = ValueNotifier(0);
    _positionSubscription = widget.player.positionDataStream.listen((data) {
      final durationMs =
          data.duration.inMilliseconds > 0
              ? data.duration.inMilliseconds
              : widget.song.duration;
      _playhead.value =
          durationMs > 0
              ? (data.position.inMilliseconds / durationMs)
                  .clamp(0.0, 1.0)
                  .toDouble()
              : 0.0;
    });
    _controller =
        VisualFeatureController()
          ..load(songId: widget.song.id, filePath: widget.song.data);
  }

  @override
  void dispose() {
    unawaited(_positionSubscription.cancel());
    _playhead.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 2, 28, 0),
      child: SizedBox(
        height: 48,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final waveform = _controller.waveform;
              if (_controller.isLoading) {
                return Center(
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: colors.primary,
                    backgroundColor: colors.onPlayerLow.withValues(alpha: 0.2),
                  ),
                );
              }
              if (waveform == null) {
                return Icon(
                  Icons.graphic_eq_rounded,
                  size: 20,
                  color: colors.onPlayerLow,
                );
              }

              return CustomPaint(
                size: Size.infinite,
                painter: WaveformPainter(
                  amplitudes: waveform.amplitudes,
                  playhead: _playhead,
                  activeColor: colors.primaryLight,
                  inactiveColor: colors.onPlayerLow.withValues(alpha: 0.32),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
