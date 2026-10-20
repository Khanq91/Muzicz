import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

/// Keeps tab state mounted while animating only the visible pages, above the dock.
class MainTabTransition extends StatefulWidget {
  const MainTabTransition({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<MainTabTransition> createState() => _MainTabTransitionState();
}

class _PagePose {
  const _PagePose(
    this.x,
    this.opacity,
    this.scale,
    this.radius,
    this.blur,
    this.dim,
  );
  static const resting = _PagePose(0, 1, 1, 0, 0, 0);
  final double x, opacity, scale, radius, blur, dim;

  _PagePose toward(_PagePose other, double t) => _PagePose(
    lerpDouble(x, other.x, t)!,
    lerpDouble(opacity, other.opacity, t)!,
    lerpDouble(scale, other.scale, t)!,
    lerpDouble(radius, other.radius, t)!,
    lerpDouble(blur, other.blur, t)!,
    lerpDouble(dim, other.dim, t)!,
  );
}

class _MainTabTransitionState extends State<MainTabTransition>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: 1,
  );
  final Map<int, _PagePose> _starts = {};
  final Map<int, _PagePose> _ends = {};
  bool _depth = false;
  bool _openingSettings = false;

  _PagePose _pose(int index, {int? activeIndex}) {
    final start = _starts[index] ?? _PagePose.resting;
    final end = _ends[index] ?? _PagePose.resting;
    final incoming = index == (activeIndex ?? widget.index);
    final time = (_controller.value *
            (incoming && _openingSettings ? 450 / 350 : 1))
        .clamp(0.0, 1.0);
    final curve =
        incoming ? const Cubic(0.2, 0, 0, 1) : const Cubic(0.3, 0, 0.8, 0.15);
    return start.toward(end, curve.transform(time));
  }

  @override
  void didUpdateWidget(covariant MainTabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    // Sample before replacing targets so rapid taps continue from the current pose.
    final poses =
        _controller.isAnimating
            ? {
              for (final i in _starts.keys)
                i: _pose(i, activeIndex: oldWidget.index),
            }
            : {oldWidget.index: _PagePose.resting};
    final direction = widget.index > oldWidget.index ? 1.0 : -1.0;
    _depth = widget.index == 2 || oldWidget.index == 2;
    _openingSettings = widget.index == 2;
    _starts
      ..clear()
      ..addAll(poses);
    _starts.putIfAbsent(
      widget.index,
      () => _PagePose(
        direction * (_openingSettings ? 1 / 3 : .25),
        0,
        _depth && !_openingSettings ? .95 : 1,
        _depth ? 32 : 0,
        0,
        0,
      ),
    );
    _ends.clear();
    for (final i in _starts.keys) {
      _ends[i] =
          i == widget.index
              ? _PagePose.resting
              : _PagePose(
                -direction * (_depth && !_openingSettings ? 1 : .25),
                0,
                _depth && !_openingSettings ? .85 : 1,
                _depth ? 32 : 0,
                _openingSettings ? 12 : 0,
                _openingSettings ? .4 : 0,
              );
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder:
        (context, _) => LayoutBuilder(
          builder:
              (context, constraints) => ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final i in [
                      for (var i = 0; i < widget.children.length; i++)
                        if (i != widget.index) i,
                      widget.index,
                    ])
                      _page(i, constraints.maxWidth),
                  ],
                ),
              ),
        ),
  );

  Widget _page(int index, double width) {
    final active = index == widget.index;
    final visible =
        active || (_controller.isAnimating && _starts.containsKey(index));
    final pose = _controller.isAnimating ? _pose(index) : _PagePose.resting;
    return Offstage(
      key: ValueKey(index),
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(
          ignoring: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: Transform.translate(
              offset: Offset(pose.x * width, 0),
              child: Transform.scale(
                scale: pose.scale,
                child: Opacity(
                  opacity: pose.opacity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(pose.radius),
                    child: ImageFiltered(
                      enabled: pose.blur > 0,
                      imageFilter: ImageFilter.blur(
                        sigmaX: pose.blur,
                        sigmaY: pose.blur,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RepaintBoundary(child: widget.children[index]),
                          if (pose.dim > 0)
                            ColoredBox(
                              color: Colors.black.withValues(alpha: pose.dim),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
