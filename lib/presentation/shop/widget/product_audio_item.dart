import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:math';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:binetatour/core/widgets/shimmer/cool_shimmer_kit.dart';

class ProductAudioItem extends StatefulWidget {
  final String audioUrl;
  final bool isMuted;
  final bool isActive;

  const ProductAudioItem({
    super.key,
    required this.audioUrl,
    required this.isMuted,
    this.isActive = true,
  });

  @override
  State<ProductAudioItem> createState() => _ProductAudioItemState();
}

class _ProductAudioItemState extends State<ProductAudioItem> {
  late final Player _player = Player();
  bool _isPlaying = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _player.setPlaylistMode(PlaylistMode.single);
    _player.setVolume(widget.isMuted ? 0.0 : 100.0);

    _player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    _player.stream.error.listen((error) {
      debugPrint('Audio Player Error: $error');
    });

    try {
      // Step 1: Download the file using Dio to bypass media_kit network issues
      final dio = Dio();
      final tempDir = Directory.systemTemp;
      // Create a unique filename based on the URL hash to avoid conflicts
      final fileName = 'audio_${widget.audioUrl.hashCode}.mp3';
      final savePath = '${tempDir.path}/$fileName';

      final file = File(savePath);

      // Only download if it doesn't already exist
      if (!await file.exists()) {
        await dio.download(widget.audioUrl, savePath);
      }

      // Step 2: Play the local file
      await _player.open(Media('file://$savePath'), play: widget.isActive);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error downloading or opening audio: $e');
    }
  }

  @override
  void didUpdateWidget(ProductAudioItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMuted != widget.isMuted) {
      _player.setVolume(widget.isMuted ? 0.0 : 100.0);
    }
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _player.play();
        setState(() => _isPlaying = true);
      } else {
        _player.pause();
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  void dispose() {
    try {
      _player.stop();
      _player.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_isPlaying) {
        _player.pause();
        _isPlaying = false;
      } else {
        _player.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: !_isInitialized
            ? const CoolShimmer(
                child: CoolShimmerBone.circle(size: 76),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AudioWave(isPlaying: _isPlaying, isReversed: true),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF6900).withValues(alpha: 0.4),
                          width: 2,
                        ),
                        color: Colors.transparent,
                      ),
                      child: Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF6900),
                          ),
                          child: Icon(
                            _isPlaying
                                ? Icons.volume_up_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _AudioWave(isPlaying: _isPlaying, isReversed: false),
                ],
              ),
      ),
    );
  }
}

class _AudioWave extends StatefulWidget {
  final bool isPlaying;
  final bool isReversed;

  const _AudioWave({required this.isPlaying, required this.isReversed});

  @override
  State<_AudioWave> createState() => _AudioWaveState();
}

class _AudioWaveState extends State<_AudioWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AudioWave oldWidget) {
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
    // Taller near the center button, fading to shorter on the edges.
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

    // If reversed (Left wave), the taller bars should be on the right (end of the list).
    // If not reversed (Right wave), the taller bars should be on the left (start of the list).
    List<double> actualHeights = widget.isReversed
        ? sideHeights
        : sideHeights.reversed.toList();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(actualHeights.length, (index) {
            // Factor to make them animate slightly out of phase
            double factor = sin(_controller.value * pi * 2 + index);
            double baseH = actualHeights[index];

            double currentHeight = widget.isPlaying
                ? baseH +
                      (factor *
                          (baseH * 0.3)) // Animate by +/- 30% of their height
                : baseH * 0.3; // When paused, they are smaller

            currentHeight = currentHeight.clamp(2.0, 80.0);

            // Opacity decreases towards the smaller bars
            double opacity = (baseH / 50).clamp(0.2, 1.0);

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
