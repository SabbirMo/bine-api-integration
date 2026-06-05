import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  final Player player;
  const FullScreenVideoPlayer({super.key, required this.player});

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late final VideoController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = VideoController(widget.player, configuration: const VideoControllerConfiguration(enableHardwareAcceleration: false));
    // 1. Hide status bar and navigation bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // 2. Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // 1. Show status bar and navigation bar again
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 2. Return to portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The Full-Screen Video
          Center(
            child: SizedBox.expand(
              child: Video(
                controller: _controller,
                controls: AdaptiveVideoControls, // Basic controls for full screen
              ),
            ),
          ),
          // Back Button to exit full screen
          Positioned(
            top: 20,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}