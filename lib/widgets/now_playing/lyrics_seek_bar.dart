import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors_data.dart';

/// PixelPlayer's 50dp capsule, 5dp wave, 30dp wavelength and 8dp thumb.
class LyricsSeekBar extends StatefulWidget {
  const LyricsSeekBar({
    super.key,
    required this.value,
    required this.duration,
    required this.playing,
    required this.onChanged,
    required this.onCommit,
  });
  final double value, duration;
  final bool playing;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double> onCommit;
  @override
  State<LyricsSeekBar> createState() => _LyricsSeekBarState();
}

class _LyricsSeekBarState extends State<LyricsSeekBar>
    with SingleTickerProviderStateMixin {
  late final _phase = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  bool _dragging = false;
  int _hapticStep = -1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(covariant LyricsSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    if (widget.playing && !MediaQuery.disableAnimationsOf(context)) {
      if (!_phase.isAnimating) _phase.repeat();
    } else {
      _phase.stop();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: c.surfaceElevated,
      borderRadius: BorderRadius.circular(50),
      child: SizedBox(
        height: 50,
        child: AnimatedBuilder(
          animation: _phase,
          builder:
              (_, child) => SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 5,
                  trackShape: _WaveTrack(
                    phase: _phase.value,
                    amplitude: widget.playing ? 3 : 0,
                  ),
                  thumbShape: _WaveThumb(dragging: _dragging),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: widget.value,
                  max: widget.duration > 0 ? widget.duration : 1,
                  activeColor: c.primary,
                  inactiveColor: c.primary.withValues(alpha: .2),
                  onChangeStart:
                      widget.onChanged == null
                          ? null
                          : (_) => setState(() => _dragging = true),
                  onChanged:
                      widget.onChanged == null
                          ? null
                          : (value) {
                            final step = (value / widget.duration * 20).toInt();
                            if (step != _hapticStep) {
                              _hapticStep = step;
                              HapticFeedback.selectionClick();
                            }
                            widget.onChanged!(value);
                          },
                  onChangeEnd: (value) {
                    setState(() => _dragging = false);
                    widget.onCommit(value);
                  },
                  semanticFormatterCallback:
                      (value) =>
                          '${value ~/ 60000}:${(value ~/ 1000 % 60).toString().padLeft(2, '0')}',
                ),
              ),
        ),
      ),
    );
  }
}

class _WaveTrack extends SliderTrackShape with BaseSliderTrackShape {
  const _WaveTrack({required this.phase, required this.amplitude});
  final double phase, amplitude;
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final canvas = context.canvas;
    final paint =
        Paint()
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    final rtl = textDirection == TextDirection.rtl;
    final start = rtl ? rect.right : rect.left;
    final end = thumbCenter.dx;
    paint.color = sliderTheme.inactiveTrackColor!;
    canvas.drawLine(
      Offset(end, rect.center.dy),
      Offset(rtl ? rect.left : rect.right, rect.center.dy),
      paint,
    );
    paint.color = sliderTheme.activeTrackColor!;
    final path = Path()..moveTo(start, rect.center.dy);
    final width = (end - start).abs();
    for (double x = 0; x <= width; x += 1) {
      final taper = math.min(1.0, math.min(x, width - x) / 8);
      path.lineTo(
        start + (rtl ? -x : x),
        rect.center.dy +
            math.sin(x / 30 * math.pi * 2 - phase * math.pi * 2) *
                amplitude *
                taper,
      );
    }
    canvas.drawPath(path, paint);
  }
}

class _WaveThumb extends SliderComponentShape {
  const _WaveThumb({required this.dragging});
  final bool dragging;
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(16, 24);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: dragging ? 6 : 16,
          height: dragging ? 24 : 16,
        ),
        const Radius.circular(8),
      ),
      Paint()..color = sliderTheme.thumbColor!,
    );
  }
}
