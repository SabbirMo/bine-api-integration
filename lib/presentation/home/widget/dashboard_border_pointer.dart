import 'dart:math';
import 'package:flutter/material.dart';

class DashedBorderPainter extends CustomPainter {
  final int itemCount;
  final Color color;

  DashedBorderPainter({
    this.itemCount = 1,
    this.color = const Color(0xFFFF6900),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final rect = Rect.fromCircle(center: center, radius: radius - 1.2);

    if (itemCount <= 1) {
      canvas.drawArc(rect, 0, 2 * pi, false, paint);
      return;
    }

    final double gapAngle = itemCount > 6 ? 0.08 : 0.12;
    final double totalGapAngle = itemCount * gapAngle;
    final double totalArcAngle = (2 * pi) - totalGapAngle;
    final double segmentAngle = totalArcAngle / itemCount;

    double startAngle = -pi / 2;

    for (int i = 0; i < itemCount; i++) {
      canvas.drawArc(rect, startAngle, segmentAngle, false, paint);
      startAngle += segmentAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.itemCount != itemCount || oldDelegate.color != color;
  }
}