import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors_data.dart';

/// Native Slider handles seeking/accessibility; a repaint-only layer draws
/// the animated wave. No progress/provider rebuild is driven by the ticker.
class WavySeekBar extends StatefulWidget {
  const WavySeekBar({
    super.key,
    required this.value,
    required this.playing,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });
  final double value;
  final bool playing;
  final ValueChanged<double> onChanged, onChangeStart, onChangeEnd;
  @override
  State<WavySeekBar> createState() => _WavySeekBarState();
}

class _WavySeekBarState extends State<WavySeekBar>
    with TickerProviderStateMixin {
  late final AnimationController _phase;
  late final AnimationController _amplitude;
  bool _dragging = false;
  @override
  void initState() {
    super.initState();
    _phase = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _amplitude = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant WavySeekBar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final enabled =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    final animate = enabled && widget.playing && !_dragging;
    if (animate) {
      if (!_phase.isAnimating) _phase.repeat();
      if (_amplitude.value != 1) _amplitude.forward();
    } else {
      _amplitude.reverse().then((_) {
        if (mounted && (!widget.playing || _dragging)) _phase.stop();
      });
      if (!enabled) {
        _phase.stop();
        _amplitude.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    _amplitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SizedBox(
      height: 48,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _WavePainter(
                phase: _phase,
                amplitude: _amplitude,
                value: widget.value,
                active: c.primary,
                inactive: c.primary.withValues(alpha: .20),
                dragging: _dragging,
              ),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.transparent,
              overlayColor: Colors.transparent,
              trackHeight: 0,
              thumbShape: SliderComponentShape.noThumb,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              value: widget.value,
              onChangeStart: (v) {
                setState(() => _dragging = true);
                _sync();
                widget.onChangeStart(v);
              },
              onChanged: widget.onChanged,
              onChangeEnd: (v) {
                setState(() => _dragging = false);
                _sync();
                widget.onChangeEnd(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.phase,
    required this.amplitude,
    required this.value,
    required this.active,
    required this.inactive,
    required this.dragging,
  }) : super(repaint: Listenable.merge([phase, amplitude]));
  final Animation<double> phase, amplitude;
  final double value;
  final Color active, inactive;
  final bool dragging;
  @override
  void paint(Canvas canvas, Size size) {
    const left = 8.0;
    final right = size.width - 8;
    final thumb = left + (right - left) * value;
    final y = size.height / 2;
    final paint =
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
    if (thumb + 14 < right) {
      canvas.drawLine(
        Offset(thumb + 14, y),
        Offset(right, y),
        paint..color = inactive,
      );
    }
    final path = Path();
    for (double x = left; x <= thumb; x += 1.5) {
      final taper = math
          .min(1.0, math.min((x - left) / 12, (thumb - x) / 12))
          .clamp(0.0, 1.0);
      final dy =
          math.sin((x - left) / 34 * math.pi * 2 - phase.value * math.pi * 2) *
          3 *
          amplitude.value *
          taper;
      if (x == left) {
        path.moveTo(x, y + dy);
      } else {
        path.lineTo(x, y + dy);
      }
    }
    canvas.drawPath(path, paint..color = active);
    canvas.drawCircle(
      Offset(thumb, y),
      dragging ? 9 : 8,
      Paint()..color = active,
    );
    canvas.drawCircle(Offset(right, y), 1.5, Paint()..color = active);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.value != value ||
      old.active != active ||
      old.inactive != inactive ||
      old.dragging != dragging;
}
