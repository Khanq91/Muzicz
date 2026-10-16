import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../theme/app_colors_data.dart';
import '../../screens/now_playing_screen.dart';

PlayerRoute playerRoute({BuildContext? source}) {
  final box = source?.findRenderObject();
  final rect =
      box is RenderBox && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
  return PlayerRoute(origin: rect);
}

/// One expanding surface, with the full player laid out once at screen size.
/// Dragging changes its clip/position; it does not relayout the player controls.
class PlayerRoute extends PageRouteBuilder<void> {
  PlayerRoute({this.origin, this.initialProgress = 0})
    : super(
        opaque: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 460),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (_, _, _) => const NowPlayingScreen(),
      );
  final Rect? origin;
  final double initialProgress;

  @override
  AnimationController createAnimationController() {
    return super.createAnimationController()..value = initialProgress;
  }

  bool _dragging = false;
  double _dragProgress = 1;

  void beginDrag() {
    if (!isCurrent || controller == null) return;
    _dragProgress = Curves.easeOutCubic.transform(controller!.value);
    _dragging = true;
    controller!.stop();
    changedInternalState();
  }

  void updateDrag(double delta, double height) {
    if (!_dragging) return;
    _dragProgress = (_dragProgress - delta / height).clamp(0.0, 1.0);
    // Inverse easeOutCubic keeps the surface under the finger on release.
    controller!.value = _inverseCurve(_dragProgress);
  }

  double _inverseCurve(double value) {
    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 18; i++) {
      final mid = (low + high) / 2;
      if (Curves.easeOutCubic.transform(mid) < value) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  void endDrag(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    if (velocity > 600 || (_dragProgress < 0.72 && velocity >= -600)) {
      navigator?.pop();
    } else {
      controller!.forward();
    }
    changedInternalState();
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final size = MediaQuery.sizeOf(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final c = context.appColors;
    final collapsed =
        origin ?? Rect.fromLTWH(16, size.height - 145, size.width - 32, 56);
    return AnimatedBuilder(
      animation: animation,
      child: RepaintBoundary(child: child),
      builder: (_, content) {
        final progress =
            reduced ? 1.0 : Curves.easeOutCubic.transform(animation.value);
        final rect = Rect.lerp(collapsed, Offset.zero & size, progress)!;
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.18 * progress),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28 * (1 - progress)),
                child: ColoredBox(
                  color: c.background,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minWidth: size.width,
                    maxWidth: size.width,
                    minHeight: size.height,
                    maxHeight: size.height,
                    child: SizedBox.fromSize(
                      size: size,
                      child: GestureDetector(
                        onVerticalDragStart: (_) => beginDrag(),
                        onVerticalDragUpdate:
                            (d) => updateDrag(d.delta.dy, size.height),
                        onVerticalDragEnd:
                            (d) => endDrag(d.primaryVelocity ?? 0),
                        onVerticalDragCancel: () => endDrag(-1000),
                        child: Opacity(
                          opacity: ((progress - 0.12) / 0.88).clamp(0, 1),
                          child: TickerMode(
                            enabled: animation.isCompleted,
                            child: content!,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (progress < 0.5)
              Positioned.fromRect(
                rect: Rect.fromLTWH(
                  rect.left + 20,
                  rect.top,
                  rect.width - 40,
                  56,
                ),
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1 - progress * 2).clamp(0, 1),
                    child: Material(
                      color: Colors.transparent,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.read<PlayerProvider>().currentSong?.title ??
                              '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Preview an expansion in the existing overlay while the finger owns the
/// gesture. Navigation is committed only on release, so Navigator cannot
/// cancel that pointer halfway through the opening drag.
class PlayerLauncher extends StatefulWidget {
  const PlayerLauncher({super.key, required this.child});
  final Widget child;
  @override
  State<PlayerLauncher> createState() => _PlayerLauncherState();
}

class _PlayerLauncherState extends State<PlayerLauncher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expansion;

  @override
  void initState() {
    super.initState();
    _expansion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  OverlayEntry? _preview;
  PlayerRoute? _previewRoute;
  double _progress = 0;
  double _distance = 1;
  bool _settling = false;
  bool _opening = false;

  Rect? _origin() {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  void _removePreview() {
    _preview?.remove();
    _preview?.dispose();
    _preview = null;
    _previewRoute?.dispose();
    _previewRoute = null;
  }

  Future<void> _open({double initial = 0, Rect? origin}) async {
    if (_opening) return;
    _opening = true;
    final route = PlayerRoute(
      origin: origin ?? _origin(),
      initialProgress: initial,
    );
    final completed = Navigator.of(context).push(route);
    WidgetsBinding.instance.addPostFrameCallback((_) => _removePreview());
    await completed;
    _opening = false;
  }

  void _start(DragStartDetails details) {
    if (_settling || _opening) return;
    _removePreview();
    _progress = 0;
    _expansion.value = 0;
    final origin = _origin();
    _distance = (origin?.top ?? MediaQuery.sizeOf(context).height).clamp(
      1.0,
      double.infinity,
    );
    _previewRoute = PlayerRoute(origin: origin);
    _preview = OverlayEntry(
      builder:
          (overlayContext) => IgnorePointer(
            child: _previewRoute!.buildTransitions(
              overlayContext,
              _expansion,
              kAlwaysDismissedAnimation,
              const NowPlayingScreen(),
            ),
          ),
    );
    Overlay.of(context).insert(_preview!);
  }

  void _update(DragUpdateDetails details) {
    if (_preview == null || _settling || _opening) return;
    _progress = (_progress - details.delta.dy / _distance).clamp(0.0, 1.0);
    _expansion.value = _previewRoute!._inverseCurve(_progress);
  }

  Future<void> _end(double velocity) async {
    if (_preview == null || _settling || _opening) return;
    if (velocity < -450 || (_progress > 0.22 && velocity < 450)) {
      await _open(initial: _expansion.value, origin: _previewRoute!.origin);
    } else {
      _settling = true;
      try {
        await _expansion.reverse().orCancel;
      } on TickerCanceled {
        return;
      }
      if (!mounted) return;
      _removePreview();
      _settling = false;
    }
  }

  @override
  void dispose() {
    _removePreview();
    _expansion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _open,
    onVerticalDragStart: _start,
    onVerticalDragUpdate: _update,
    onVerticalDragEnd: (d) => _end(d.primaryVelocity ?? 0),
    onVerticalDragCancel: () => _end(1000),
    child: widget.child,
  );
}
