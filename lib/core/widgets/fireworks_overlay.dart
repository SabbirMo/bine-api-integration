import 'dart:math';
import 'package:flutter/material.dart';

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double opacity = 1.0;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
  });

  void update() {
    x += vx;
    y += vy;
    vy += 0.15; // Gravity pull
    vx *= 0.98; // Air resistance
    vy *= 0.98; // Air resistance
    opacity -= 0.015; // Particle fade speed
    if (opacity < 0) opacity = 0;
  }
}

class FireworksOverlay {
  static void show(BuildContext context) {
    try {
      final overlayState = Overlay.of(context);
      late OverlayEntry overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (context) => _FireworksWidget(
          onComplete: () {
            try {
              overlayEntry.remove();
            } catch (e) {
              debugPrint("Error removing fireworks overlay: $e");
            }
          },
        ),
      );

      overlayState.insert(overlayEntry);
    } catch (e) {
      debugPrint("Could not show fireworks overlay: $e");
    }
  }
}

class _FireworksWidget extends StatefulWidget {
  final VoidCallback onComplete;

  const _FireworksWidget({required this.onComplete});

  @override
  State<_FireworksWidget> createState() => _FireworksWidgetState();
}

class _FireworksWidgetState extends State<_FireworksWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();
  bool _burstsInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _controller.addListener(() {
      setState(() {
        for (var particle in _particles) {
          particle.update();
        }
        _particles.removeWhere((p) => p.opacity <= 0);
      });
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  void _initializeBursts(Size size) {
    // Fire multiple fireworks bursts
    _createBurst(size, 0.5, 0.4); // Middle-center burst

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _createBurst(size, 0.3, 0.35); // Left-center burst
      }
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _createBurst(size, 0.7, 0.3); // Right-center burst
      }
    });
  }

  void _createBurst(Size size, double relativeX, double relativeY) {
    final startX = size.width * relativeX;
    final startY = size.height * relativeY;

    final colors = [
      const Color(0xFFFF6900), // App primary brand orange
      Colors.amberAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.cyanAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
    ];

    final particleCount = 45 + _random.nextInt(15);
    for (int i = 0; i < particleCount; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 3.0 + _random.nextDouble() * 7.0;
      final color = colors[_random.nextInt(colors.length)];
      final particleSize = 3.0 + _random.nextDouble() * 4.0;

      _particles.add(
        Particle(
          x: startX,
          y: startY,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: color,
          size: particleSize,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_burstsInitialized) {
          _burstsInitialized = true;
          // Defer the burst generation slightly so we do not call setState during layout phase
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _initializeBursts(size);
            }
          });
        }
        return IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter: FireworksPainter(_particles),
          ),
        );
      },
    );
  }
}

class FireworksPainter extends CustomPainter {
  final List<Particle> particles;

  FireworksPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      if (p.opacity <= 0) continue;
      // ignore: deprecated_member_use
      paint.color = p.color.withOpacity(p.opacity);
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);

      // Draw secondary trail effect
      if (p.opacity > 0.45) {
        // ignore: deprecated_member_use
        paint.color = p.color.withOpacity(p.opacity * 0.25);
        canvas.drawCircle(
          Offset(p.x - p.vx * 0.6, p.y - p.vy * 0.6),
          p.size * 0.75,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
