import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class HomeProductCard extends StatefulWidget {
  final String videoUrl;
  final String assetThumbnail;
  final String title;
  final String price;
  final String? oldPrice;
  final String? discount;

  const HomeProductCard({
    super.key,
    required this.videoUrl,
    required this.assetThumbnail,
    required this.title,
    required this.price,
    this.oldPrice,
    this.discount,
  });

  @override
  State<HomeProductCard> createState() => _HomeProductCardState();
}

class _HomeProductCardState extends State<HomeProductCard> {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _hasError = false;

  Future<void> _playVideo() async {
    if (_isInitializing) return;

    setState(() {
      _isInitializing = true;
      _hasError = false;
    });

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      await _controller!.initialize();

      if (!mounted) return;

      await _controller!.setLooping(true);
      await _controller!.play();

      setState(() => _isInitializing = false);
    } catch (e) {
      debugPrint('Video Init Error: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
        });
        _controller?.dispose();
        _controller = null;
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
    });
  }

  bool get _isVideoReady =>
      _controller != null && _controller!.value.isInitialized;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isVideoReady ? _togglePlayPause : _playVideo,
      child: Container(
        width: 160,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Thumbnail
            Image.asset(
              widget.assetThumbnail,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade900,
                child: const Icon(Icons.image_not_supported,
                    color: Colors.white38),
              ),
            ),

            // 2. Video Layer
            if (_isVideoReady)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),

            // 3. Dark Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),

            // 4. Discount Badge (Top Left)
            if (widget.discount != null)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.discount!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // 5. Play / Pause Icon (Center) — shown when not playing
            if (!_isInitializing && !_hasError)
              if (!_isVideoReady ||
                  (_isVideoReady && !_controller!.value.isPlaying))
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isVideoReady ? Icons.play_arrow_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),

            // 6. Loading Indicator
            if (_isInitializing)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),

            // 7. Error State
            if (_hasError)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: Colors.white70, size: 28),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap to retry',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),

            // 8. Product Details (Bottom)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        widget.price,
                        style: const TextStyle(
                          color: Color(0xFFE8500A),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.oldPrice != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          widget.oldPrice!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}