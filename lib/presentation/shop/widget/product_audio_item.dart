import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class ProductAudioItem extends StatefulWidget {
  final String audioUrl;
  final bool isMuted;

  const ProductAudioItem({super.key, required this.audioUrl, required this.isMuted});

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
    _player.setPlaylistMode(PlaylistMode.loop);
    _player.setVolume(widget.isMuted ? 0.0 : 100.0);
    await _player.open(Media(widget.audioUrl));
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
        _isPlaying = true;
      });
    }
  }

  @override
  void didUpdateWidget(ProductAudioItem oldWidget) {
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
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.audiotrack, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            if (!_isInitialized)
              const CircularProgressIndicator(color: Color(0xFFFF6900))
            else
              IconButton(
                iconSize: 64,
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: const Color(0xFFFF6900),
                ),
                onPressed: _togglePlay,
              ),
          ],
        ),
      ),
    );
  }
}
