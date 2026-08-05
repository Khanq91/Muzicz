import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/song_item.dart';
import '../../../providers/player_provider.dart';
import '../../../services/audio_handler.dart';
import '../core/visual_feature_flag.dart';
import '../providers/visual_feature_controller.dart';
import '../providers/visual_mode_provider.dart';

/// Preserves the original rotating cover in Normal mode and creates the
/// amplitude-driven subtree only while Fancy mode is active.
final class ReactiveCoverArtTransform extends StatelessWidget {
  const ReactiveCoverArtTransform({
    super.key,
    required this.song,
    required this.player,
    required this.normalRotation,
    required this.child,
  });

  final SongItem song;
  final PlayerProvider player;
  final AnimationController normalRotation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fancy =
        kMusicVisualFeatureEnabled &&
        context.select<VisualModeProvider, bool>(
          (provider) => provider.mode.enablesReactiveVisual,
        );

    if (!fancy) {
      return _NormalCoverRotation(
        player: player,
        rotation: normalRotation,
        child: child,
      );
    }

    return _ActiveCoverPulse(
      key: ValueKey(song.id),
      song: song,
      player: player,
      normalRotation: normalRotation,
      child: child,
    );
  }
}

final class _NormalCoverRotation extends StatefulWidget {
  const _NormalCoverRotation({
    required this.player,
    required this.rotation,
    required this.child,
  });

  final PlayerProvider player;
  final AnimationController rotation;
  final Widget child;

  @override
  State<_NormalCoverRotation> createState() => _NormalCoverRotationState();
}

final class _NormalCoverRotationState extends State<_NormalCoverRotation> {
  @override
  void initState() {
    super.initState();
    if (widget.player.isPlaying && !widget.rotation.isAnimating) {
      widget.rotation.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.rotation,
      builder:
          (_, child) => Transform.rotate(
            angle: widget.rotation.value * 2 * 3.14159,
            child: child,
          ),
      child: widget.child,
    );
  }
}

final class _ActiveCoverPulse extends StatefulWidget {
  const _ActiveCoverPulse({
    super.key,
    required this.song,
    required this.player,
    required this.normalRotation,
    required this.child,
  });

  final SongItem song;
  final PlayerProvider player;
  final AnimationController normalRotation;
  final Widget child;

  @override
  State<_ActiveCoverPulse> createState() => _ActiveCoverPulseState();
}

final class _ActiveCoverPulseState extends State<_ActiveCoverPulse> {
  late final VisualFeatureController _controller;
  late final StreamSubscription<PositionData> _positionSubscription;
  late bool _wasPlaying;
  double _lastPlayhead = 0;

  @override
  void initState() {
    super.initState();
    _wasPlaying = widget.player.isPlaying;
    widget.normalRotation.stop();
    _controller =
        VisualFeatureController()
          ..load(songId: widget.song.id, filePath: widget.song.data);
    _positionSubscription = widget.player.positionDataStream.listen(
      _onPosition,
    );
    widget.player.addListener(_onPlayerChange);
  }

  void _onPosition(PositionData data) {
    final durationMs =
        data.duration.inMilliseconds > 0
            ? data.duration.inMilliseconds
            : widget.song.duration;
    _lastPlayhead =
        durationMs > 0
            ? (data.position.inMilliseconds / durationMs)
                .clamp(0.0, 1.0)
                .toDouble()
            : 0;
    _controller.updatePlayhead(
      _lastPlayhead,
      isPlaying: widget.player.isPlaying,
    );
  }

  void _onPlayerChange() {
    if (widget.normalRotation.isAnimating) widget.normalRotation.stop();
    final isPlaying = widget.player.isPlaying;
    if (isPlaying == _wasPlaying) return;
    _wasPlaying = isPlaying;
    if (isPlaying) {
      // The parent preserves its legacy rotation controller for Normal mode.
      // Keep it dormant while this Fancy-only pulse subtree is mounted.
      widget.normalRotation.stop();
      _controller.updatePlayhead(_lastPlayhead, isPlaying: true);
    } else {
      _controller.resetAmplitude();
    }
  }

  @override
  void dispose() {
    widget.player.removeListener(_onPlayerChange);
    unawaited(_positionSubscription.cancel());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder:
            (context, child) => AnimatedScale(
              scale: 1 + (_controller.amplitude * 0.055),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: child,
            ),
      ),
    );
  }
}
