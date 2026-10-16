import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dock_motion.dart';
import '../core/app_strings.dart';

class TrackSwipe extends StatefulWidget {
  const TrackSwipe({
    super.key,
    required this.child,
    required this.onNext,
    required this.onPrevious,
  });
  final Widget child;
  final Future<void> Function() onNext;
  final Future<void> Function() onPrevious;

  @override
  State<TrackSwipe> createState() => _TrackSwipeState();
}

class _TrackSwipeState extends State<TrackSwipe>
    with SingleTickerProviderStateMixin {
  late final _offset = AnimationController.unbounded(vsync: this)
    ..addListener(_notifyDock);
  double _width = 1;
  bool _busy = false;
  bool _returning = false;
  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  void _notifyDock() {
    if (mounted && !_returning) {
      DockSwipeNotification(_offset.value / _width).dispatch(context);
    }
  }

  Future<void> _returnHome() async {
    _returning = true;
    const DockSwipeNotification(0, release: true).dispatch(context);
    try {
      await _offset
          .animateTo(
            0,
            duration:
                _reduced ? Duration.zero : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
    } on TickerCanceled {
      // A new drag owns the offset now, or this mini player was dismissed.
    }
  }

  Future<void> _finish(double velocity) async {
    if (_busy) return;
    final commit = _offset.value.abs() > _width * 0.22 || velocity.abs() > 450;
    if (!commit) {
      await _returnHome();
      return;
    }
    _busy = true;
    final direction = velocity.abs() > 450 ? velocity.sign : _offset.value.sign;
    try {
      await _offset
          .animateTo(
            direction * _width,
            duration:
                _reduced ? Duration.zero : const Duration(milliseconds: 130),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
      if (!mounted) return;
      await (direction < 0 ? widget.onNext() : widget.onPrevious());
      if (!mounted) return;
      HapticFeedback.selectionClick();
      _offset.value = -direction * _width * 0.65;
      await _returnHome();
    } on TickerCanceled {
      // The dock was removed during a transition.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text(AppStrings.trackChangeFailed)),
        );
      }
    } finally {
      _busy = false;
      if (mounted) {
        final needsRelease = !_returning;
        _returning = true;
        _offset.value = 0;
        if (needsRelease) {
          const DockSwipeNotification(0, release: true).dispatch(context);
        }
      }
    }
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      _width = constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          if (!_busy) {
            _offset.stop();
            _returning = false;
          }
        },
        onHorizontalDragUpdate: (d) {
          if (!_busy) {
            _offset.value = (_offset.value + d.delta.dx).clamp(-_width, _width);
          }
        },
        onHorizontalDragEnd: (d) => _finish(d.primaryVelocity ?? 0),
        onHorizontalDragCancel: () {
          if (!_busy) _returnHome();
        },
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _offset,
            child: widget.child,
            builder:
                (_, child) => Transform.translate(
                  offset: Offset(_reduced ? 0 : _offset.value, 0),
                  child: Opacity(
                    opacity:
                        _reduced
                            ? 1
                            : (1 - _offset.value.abs() / _width).clamp(0, 1),
                    child: child,
                  ),
                ),
          ),
        ),
      );
    },
  );
}
