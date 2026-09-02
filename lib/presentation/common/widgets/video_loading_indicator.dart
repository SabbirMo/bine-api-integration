import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Sleek, high-performance loading animation widget for video buffering & preloading.
/// Replaces generic CircularProgressIndicator with a modern Lottie animation.
class VideoLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const VideoLoadingIndicator({
    super.key,
    this.size = 56.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          padding: EdgeInsets.all(size * 0.15),
          child: Lottie.asset(
            'assets/lottie/video_loading.json',
            width: size * 0.7,
            height: size * 0.7,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Elegant fallback in case asset fails
              return const CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE8500A)),
              );
            },
          ),
        ),
      ),
    );
  }
}
