import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/product_provider.dart';

class ProductVideoItem extends StatefulWidget {
  final int productId;
  final String videoUrl;
  final bool isMuted;

  const ProductVideoItem({
    super.key,
    required this.productId,
    required this.videoUrl,
    required this.isMuted,
  });

  @override
  State<ProductVideoItem> createState() => _ProductVideoItemState();
}

class _ProductVideoItemState extends State<ProductVideoItem> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player, configuration: const VideoControllerConfiguration(enableHardwareAcceleration: false));

  bool _hasError = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _player.setPlaylistMode(PlaylistMode.loop);
      _player.setVolume(widget.isMuted ? 0.0 : 100.0);
      await _player.open(Media(widget.videoUrl));
      
      // Record that this video was viewed!
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        context.read<ProductProvider>().trackVideoView(widget.productId);
      }
    } catch (error) {
      debugPrint('Video Player Error: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(ProductVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMuted != widget.isMuted) {
      _player.setVolume(widget.isMuted ? 0.0 : 100.0);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 50,
        ),
      );
    }
    
    return Center(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Video(
            controller: _controller,
            controls: NoVideoControls, // Since they have custom UI on top
            fill: Colors.transparent, 
          ),
          if (!_isInitialized)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6900)),
            ),
        ],
      ),
    );
  }
}
