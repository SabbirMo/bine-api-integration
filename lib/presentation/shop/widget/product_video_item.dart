import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/product_provider.dart';
import 'package:binetatour/core/base_url/base_url.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';

class ProductVideoItem extends StatefulWidget {
  final int productId;
  final String videoUrl;
  final String? fallbackUrl;
  final String? thumbnailUrl;
  final bool isMuted;
  final bool isActive;

  const ProductVideoItem({
    super.key,
    required this.productId,
    required this.videoUrl,
    this.fallbackUrl,
    this.thumbnailUrl,
    required this.isMuted,
    this.isActive = true,
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
  bool _hasStartedPlaying = false;

  String get _resolvedVideoUrl {
    String url = widget.videoUrl.trim();
    if (url.isEmpty && widget.fallbackUrl != null) {
      url = widget.fallbackUrl!.trim();
    }
    return _resolveUrl(url);
  }

  String _resolveUrl(String rawUrl) {
    String url = rawUrl.trim();
    if (url.isNotEmpty &&
        !url.startsWith('http') &&
        !url.startsWith('file://') &&
        !url.startsWith('/data')) {
      final base = BaseUrl.baseUrl;
      if (url.startsWith('/')) {
        url = '$base$url';
      } else {
        url = '$base/$url';
      }
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    if (_isInitializing || _player != null) return;

    setState(() {
      _isInitializing = true;
      _hasError = false;
      _hasStartedPlaying = false;
    });

    try {
      final cleanUrl = _resolvedVideoUrl;
      if (cleanUrl.isEmpty) {
        throw Exception('Empty video URL');
      }

      _player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 1024 * 1024,
          logLevel: MPVLogLevel.warn,
        ),
      );

      _controller = VideoController(
        _player!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      _player!.setPlaylistMode(PlaylistMode.loop);
      _player!.setVolume(widget.isMuted ? 0.0 : 100.0);

      try {
        final platform = _player!.platform;
        if (platform != null) {
          (platform as dynamic).setProperty('hls-bitrate', 'auto');
          (platform as dynamic).setProperty('cache', 'yes');
        }
      } catch (_) {}

      _player!.stream.width.listen((_) {
        if (mounted) {
          setState(() {});
        }
      });
      _player!.stream.height.listen((_) {
        if (mounted) {
          setState(() {});
        }
      });

      _player!.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _isPlaying = playing;
            if (playing && _hasStartedPlaying) {
              _isInitializing = false;
            }
          });
        }
      });

      _player!.stream.position.listen((pos) {
        if (mounted && pos > Duration.zero && !_hasStartedPlaying) {
          setState(() {
            _hasStartedPlaying = true;
            _isInitializing = false;
          });
        }
      });

      // 1. Get cached local file if already downloaded for instant 0ms playback
      final cachedPath = VideoCacheManager.instance.getCachedFilePath(cleanUrl);
      final playPath = cachedPath ?? cleanUrl;

      // 2. Open media with autoPlay if active
      await _player!.open(Media(playPath), play: widget.isActive);

      // If not cached yet, trigger background caching
      if (cachedPath == null) {
        VideoCacheManager.instance.preCacheVideo(cleanUrl);
      }

      if (mounted) {
        context.read<ProductProvider>().trackVideoView(widget.productId);
      }
    } catch (error) {
      debugPrint('Video Player Error: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitializing = false;
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
    if (oldWidget.videoUrl != widget.videoUrl) {
      _player?.dispose();
      _player = null;
      _controller = null;
      if (widget.isActive) {
        _initPlayer();
      }
    } else {
      if (oldWidget.isMuted != widget.isMuted && _player != null) {
        _player!.setVolume(widget.isMuted ? 0.0 : 100.0);
      }
      if (oldWidget.isActive != widget.isActive) {
        if (widget.isActive) {
          if (_player == null) {
            _initPlayer();
          } else {
            _player!.play();
          }
        } else {
          _player?.pause();
        }
      }
    }
  }

  @override
  void dispose() {
    try {
      _player?.stop();
      _player?.dispose();
    } catch (_) {}
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

    final double? rawW = _player?.state.width?.toDouble();
    final double? rawH = _player?.state.height?.toDouble();
    final bool hasValidDimensions =
        rawW != null && rawW > 0 && rawH != null && rawH > 0;
    final double videoWidth = hasValidDimensions ? rawW : 16.0;
    final double videoHeight = hasValidDimensions ? rawH : 9.0;

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
            // 1. Blurred Background Layer using CDN thumbnail
            if (widget.thumbnailUrl != null &&
                widget.thumbnailUrl!.trim().isNotEmpty)
              Positioned.fill(
                child: ClipRect(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                    child: Image.network(
                      widget.thumbnailUrl!,
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.35),
                      colorBlendMode: BlendMode.darken,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: Colors.black),
                    ),
                  ),
                ),
              )
            else
              Container(color: Colors.black),

            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.25)),
            ),

            // 2. Video Player Layer (Always attached to surface when ready)
            if (_isVideoReady)
              Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: videoWidth,
                    height: videoHeight,
                    child: RepaintBoundary(
                      child: Video(
                        controller: _controller!,
                        controls: NoVideoControls,
                        fill: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),

            // 3. Instant Thumbnail / Poster Layer with Smooth Fade
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              opacity: _hasStartedPlaying ? 0.0 : 1.0,
              child: IgnorePointer(
                child:
                    widget.thumbnailUrl != null &&
                        widget.thumbnailUrl!.trim().isNotEmpty
                    ? Image.network(
                        widget.thumbnailUrl!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.black),
                      )
                    : Container(color: Colors.black),
              ),
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
