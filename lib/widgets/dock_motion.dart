import 'package:flutter/material.dart';

/// Local gesture channel: dragging the mini player only repaints the dock.
class DockSwipeNotification extends Notification {
  const DockSwipeNotification(this.progress, {this.release = false});
  final double progress;
  final bool release;
}

class DockMotion extends StatefulWidget {
  const DockMotion({super.key, required this.child, required this.expanded});
  final Widget child;
  final bool expanded;

  @override
  State<DockMotion> createState() => _DockMotionState();
}

class _DockMotionState extends State<DockMotion>
    with SingleTickerProviderStateMixin {
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);
  bool _swiping = false;
  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  void _settle() {
    _scale.animateTo(
      1,
      duration: _reduced ? Duration.zero : const Duration(milliseconds: 480),
      curve: const Cubic(0.34, 1.56, 0.64, 1),
    );
  }

  @override
  void didUpdateWidget(covariant DockMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.expanded && widget.expanded && !_reduced) {
      _scale.value = 0.96;
      _settle();
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<DockSwipeNotification>(
        onNotification: (event) {
          _swiping = !event.release;
          if (event.release) {
            _settle();
          } else {
            _scale.value =
                _reduced ? 1 : 1 - event.progress.abs().clamp(0, 1) * 0.10;
          }
          return true;
        },
        child: Listener(
          onPointerDown: (_) {
            if (!_reduced) {
              _scale.animateTo(
                0.96,
                duration: const Duration(milliseconds: 90),
              );
            }
          },
          onPointerUp: (_) {
            if (!_swiping) _settle();
          },
          onPointerCancel: (_) {
            if (!_swiping) _settle();
          },
          child: AnimatedBuilder(
            animation: _scale,
            child: widget.child,
            builder:
                (_, child) => Transform.scale(
                  key: const ValueKey('dock-interaction-scale'),
                  scale: _scale.value,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
          ),
        ),
      );
}
