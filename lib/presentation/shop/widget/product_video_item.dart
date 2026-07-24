import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/product_provider.dart';

class ProductVideoItem extends StatefulWidget {
  final int productId;
  final String videoUrl;
  final String? thumbnailUrl;
  final bool isMuted;

  const ProductVideoItem({
    super.key,
    required this.productId,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.isMuted,
  });

  @override
  State<ProductVideoItem> createState() => _ProductVideoItemState();
}

class _ProductVideoItemState extends State<ProductVideoItem> {
  Player? _player;
  VideoController? _controller;

  bool _hasError = false;
  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _hasStartedPlaying = false;

  void _updateStartedPlayingState() {
    if (_isPlaying && !_isBuffering) {
      _hasStartedPlaying = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (_isInitializing || _player != null) return;

    setState(() {
      _isInitializing = true;
      _hasError = false;
      _isBuffering = true;
      _hasStartedPlaying = false;
    });

    try {
      _player = Player();
      _controller = VideoController(
        _player!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: false,
        ),
      );

      _player!.setPlaylistMode(PlaylistMode.single);
      _player!.setVolume(widget.isMuted ? 0.0 : 100.0);

      _player!.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _isPlaying = playing;
            _updateStartedPlayingState();
            if (playing) _isInitializing = false;
          });
        }
      });

      _player!.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() {
            _isBuffering = buffering;
            _updateStartedPlayingState();
          });
        }
      });

      _player!.stream.width.listen((width) {
        if (mounted) setState(() {});
      });

      _player!.stream.height.listen((height) {
        if (mounted) setState(() {});
      });

      await _player!.open(Media(widget.videoUrl));

      if (mounted) {
        context.read<ProductProvider>().trackVideoView(widget.productId);
      }
    } catch (error) {
      debugPrint('Video Player Error: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitializing = false;
          _isBuffering = false;
          _hasStartedPlaying = false;
        });
        _player?.dispose();
        _player = null;
        _controller = null;
      }
    }
  }

  bool get _isVideoReady => _player != null && _controller != null;

  @override
  void didUpdateWidget(ProductVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMuted != widget.isMuted && _player != null) {
      _player!.setVolume(widget.isMuted ? 0.0 : 100.0);
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _initPlayer, child: const Text('Retry')),
          ],
        ),
      );
    }

    final double videoWidth = _player?.state.width?.toDouble() ?? 16.0;
    final double videoHeight = _player?.state.height?.toDouble() ?? 9.0;

    return GestureDetector(
      onTap: () {
        if (_isVideoReady) {
          setState(() {
            _isPlaying ? _player!.pause() : _player!.play();
          });
        }
      },
      child: Center(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isVideoReady)
              Stack(
                fit: StackFit.expand,
                children: [
                  // Blurred Background Video
                  Positioned.fill(
                    child: ClipRect(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: 15.0,
                          sigmaY: 15.0,
                        ),
                        child: FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: videoWidth,
                            height: videoHeight,
                            child: Video(
                              controller: _controller!,
                              controls: NoVideoControls,
                              fill: Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Dark overlay to dim the background
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.25),
                    ),
                  ),
                  // Foreground Clear Video
                  Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: videoWidth,
                        height: videoHeight,
                        child: Video(
                          controller: _controller!,
                          controls: NoVideoControls,
                          fill: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            if (!_isVideoReady || !_isPlaying || !_hasStartedPlaying)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: widget.thumbnailUrl != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            // Blurred background thumbnail
                            Positioned.fill(
                              child: ClipRect(
                                child: ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                    sigmaX: 15.0,
                                    sigmaY: 15.0,
                                  ),
                                  child: Image.network(
                                    widget.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    color: Colors.black.withValues(alpha: 0.35),
                                    colorBlendMode: BlendMode.darken,
                                    errorBuilder: (_, _, _) => const SizedBox(),
                                  ),
                                ),
                              ),
                            ),
                            // Clear foreground thumbnail
                            Center(
                              child: Image.network(
                                widget.thumbnailUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const SizedBox(),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(),
                ),
              ),

            if (_isInitializing || (_hasStartedPlaying && _isBuffering))
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6900)),
              ),

            // Play icon overlay when paused
            if (!_isPlaying && _isVideoReady && !_isInitializing)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
