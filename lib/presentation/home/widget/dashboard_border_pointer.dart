import 'dart:math';
import 'package:flutter/material.dart';

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 9, dashSpace = 5, startBerder = 0;
    final paint = Paint()
      ..color = const Color(0xFFFF6900)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    double radius = size.width / 2;
    double circumference = 2 * pi * radius;

    while (startBerder < circumference) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        2 * pi * startBerder / circumference,
        2 * pi * dashWidth / circumference,
        false,
        paint,
      );
      startBerder += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}