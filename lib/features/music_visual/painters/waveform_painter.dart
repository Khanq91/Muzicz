import 'dart:math' as math;

import 'package:flutter/material.dart';

final class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.amplitudes,
    required this.playhead,
    required this.activeColor,
    required this.inactiveColor,
  }) : super(repaint: playhead);

  final List<double> amplitudes;
  final ValueListenable<double> playhead;
  final Color activeColor;
  final Color inactiveColor;
  late final Paint _activePaint =
      Paint()
        ..color = activeColor
        ..strokeCap = StrokeCap.round;
  late final Paint _inactivePaint =
      Paint()
        ..color = inactiveColor
        ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty || size.isEmpty) return;

    final spacing = size.width / amplitudes.length;
    final strokeWidth = math.max(0.75, spacing * 0.58);
    final centerY = size.height / 2;
    final minimumBarHeight = math.min(2.0, size.height);
    _inactivePaint.strokeWidth = strokeWidth;
    _activePaint.strokeWidth = strokeWidth;

    _drawBars(canvas, size, spacing, centerY, minimumBarHeight, _inactivePaint);

    final playedWidth = playhead.value.clamp(0.0, 1.0).toDouble() * size.width;
    if (playedWidth <= 0) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, playedWidth, size.height));
    _drawBars(canvas, size, spacing, centerY, minimumBarHeight, _activePaint);
    canvas.restore();
  }

  void _drawBars(
    Canvas canvas,
    Size size,
    double spacing,
    double centerY,
    double minimumBarHeight,
    Paint paint,
  ) {
    for (var i = 0; i < amplitudes.length; i++) {
      final normalized = amplitudes[i].clamp(0.0, 1.0);
      final height = math.max(minimumBarHeight, normalized * size.height);
      final x = (i + 0.5) * spacing;
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
        oldDelegate.playhead != playhead ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
