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
    _controller = VideoController(
      widget.player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: false,
      ),
    );
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
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
              child: MaterialVideoControlsTheme(
                normal: MaterialVideoControlsThemeData(
                  buttonBarHeight: 28.0,
                  bottomButtonBarMargin: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 28,
                  ),
                  bottomButtonBar: [
                    const MaterialPositionIndicator(),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.fullscreen_exit_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                  seekBarMargin: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  seekBarContainerHeight: 24.0,
                  seekBarHeight: 3.5,
                  seekBarAlignment: Alignment.bottomCenter,
                  padding: EdgeInsets.zero,
                ),
                fullscreen: MaterialVideoControlsThemeData(
                  buttonBarHeight: 28.0,
                  bottomButtonBarMargin: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 28,
                  ),
                  bottomButtonBar: [
                    const MaterialPositionIndicator(),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.fullscreen_exit_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                  seekBarMargin: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  seekBarContainerHeight: 24.0,
                  seekBarHeight: 3.5,
                  seekBarAlignment: Alignment.bottomCenter,
                  padding: EdgeInsets.zero,
                ),
                child: Video(
                  controller: _controller,
                  controls: MaterialVideoControls,
                ),
              ),
            ),
          ),
          // Back Button to exit full screen safely below notch/dynamic island
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 14, left: 16),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
