import 'dart:math';
import 'package:flutter/material.dart';

class StoryAudioWave extends StatefulWidget {
  final bool isPlaying;
  final bool isReversed;

  const StoryAudioWave({
    super.key,
    required this.isPlaying,
    required this.isReversed,
  });

  @override
  State<StoryAudioWave> createState() => _StoryAudioWaveState();
}

class _StoryAudioWaveState extends State<StoryAudioWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(StoryAudioWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
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
    final List<double> sideHeights = [
      4,
      6,
      8,
      12,
      10,
      16,
      20,
      14,
      24,
      30,
      22,
      36,
      44,
      32,
      50,
      40,
    ];
    final List<double> actualHeights = widget.isReversed
        ? sideHeights
        : sideHeights.reversed.toList();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(actualHeights.length, (index) {
            final double factor = sin(_controller.value * pi * 2 + index);
            final double baseH = actualHeights[index];
            double currentHeight = widget.isPlaying
                ? baseH + (factor * (baseH * 0.3))
                : baseH * 0.3;
            currentHeight = currentHeight.clamp(2.0, 80.0);
            final double opacity = (baseH / 50).clamp(0.2, 1.0);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: currentHeight,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6900).withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
