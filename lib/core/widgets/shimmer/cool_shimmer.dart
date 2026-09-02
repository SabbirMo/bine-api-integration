import 'package:flutter/material.dart';

/// Direction for the shimmer gradient sweep animation.
enum ShimmerDirection {
  ltr, // Left to Right
  rtl, // Right to Left
  ttb, // Top to Bottom
  btt, // Bottom to Top
}

/// Base Shimmer Wrapper that animates an elegant gradient sheen over its child.
///
/// Automatically detects Dark/Light mode theme colors when [baseColor]
/// or [highlightColor] are omitted.
class CoolShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;
  final ShimmerDirection direction;
  final bool enabled;

  const CoolShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor,
    this.highlightColor,
    this.direction = ShimmerDirection.ltr,
    this.enabled = true,
  });

  /// Factory for a subtle warm brand-tinted shimmer (matching brand #FF8A00 / #FF6900)
  factory CoolShimmer.brand({
    Key? key,
    required Widget child,
    Duration duration = const Duration(milliseconds: 1500),
    ShimmerDirection direction = ShimmerDirection.ltr,
    bool enabled = true,
  }) {
    return CoolShimmer(
      key: key,
      duration: duration,
      baseColor: const Color(0xFFF7EFE6),
      highlightColor: const Color(0xFFFFF9F2),
      direction: direction,
      enabled: enabled,
      child: child,
    );
  }

  @override
  State<CoolShimmer> createState() => _CoolShimmerState();
}

class _CoolShimmerState extends State<CoolShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CoolShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme adaptive fallback colors
    final base = widget.baseColor ??
        (isDark ? const Color(0xFF262629) : const Color(0xFFEBEBEB));
    final highlight = widget.highlightColor ??
        (isDark ? const Color(0xFF3B3D44) : const Color(0xFFF7F7F7));

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = _controller.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return _createGradient(t, bounds, base, highlight);
            },
            child: child,
          );
        },
      ),
    );
  }

  Shader _createGradient(
    double t,
    Rect bounds,
    Color base,
    Color highlight,
  ) {
    final offset = -1.0 + (t * 3.0);

    Alignment begin;
    Alignment end;

    switch (widget.direction) {
      case ShimmerDirection.ltr:
        begin = Alignment(offset - 1.0, 0.0);
        end = Alignment(offset + 1.0, 0.0);
        break;
      case ShimmerDirection.rtl:
        begin = Alignment(-offset + 1.0, 0.0);
        end = Alignment(-offset - 1.0, 0.0);
        break;
      case ShimmerDirection.ttb:
        begin = Alignment(0.0, offset - 1.0);
        end = Alignment(0.0, offset + 1.0);
        break;
      case ShimmerDirection.btt:
        begin = Alignment(0.0, -offset + 1.0);
        end = Alignment(0.0, -offset - 1.0);
        break;
    }

    return LinearGradient(
      begin: begin,
      end: end,
      stops: const [0.1, 0.5, 0.9],
      colors: [base, highlight, base],
      tileMode: TileMode.clamp,
    ).createShader(bounds);
  }
}

/// Atomic skeleton block that fills shapes with solid white (which gets colored by CoolShimmer).
class CoolShimmerBone extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final ShapeBorder? shapeBorder;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;

  const CoolShimmerBone({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.margin,
  })  : shape = BoxShape.rectangle,
        shapeBorder = null;

  const CoolShimmerBone.circle({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = 0,
        shape = BoxShape.circle,
        shapeBorder = null;

  const CoolShimmerBone.pill({
    super.key,
    this.width,
    this.height = 24,
    this.margin,
  })  : borderRadius = 999,
        shape = BoxShape.rectangle,
        shapeBorder = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(borderRadius),
      ),
    );
  }
}
