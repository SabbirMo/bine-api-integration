import 'dart:async';
import 'package:binetatour/presentation/home/widget/full_screen_player.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlaceholder extends StatefulWidget {
  final String link;
  final String? thumbnailUrl;

  const VideoPlaceholder({super.key, required this.link, this.thumbnailUrl});

  @override
  State<VideoPlaceholder> createState() => _VideoPlaceholderState();
}

class _VideoPlaceholderState extends State<VideoPlaceholder> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = false;
  bool _isMuted = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.link))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.setLooping(true);
          _controller.setVolume(0); // Default muted
          _controller.play();
        }
      });

    // Listen for time updates to refresh the timer and slider
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Logic to show controls on click/hover and hide after 3 seconds
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    _hideTimer?.cancel();
    if (_showControls) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  // Formats Duration to mm:ss as seen in image_bf37dd.png
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _showControls = true),
      onExit: (_) => setState(() => _showControls = false),
      child: GestureDetector(
        onTap: _toggleControls,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Thumbnail / Loading State
                if (!_isInitialized)
                  widget.thumbnailUrl != null
                      ? Image.network(widget.thumbnailUrl!, fit: BoxFit.cover)
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),

                // 2. The Video Player
                if (_isInitialized)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),

                // 3. Dark Gradient Overlay for readability
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Center Play/Pause Circle (image_bf37dd.png style)
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 45,
                        ),
                      ),
                    ),
                  ),
                ),

                // 5. Bottom Controls (Timer, Icons, Slider)
                if (_isInitialized)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    bottom: _showControls ? 10 : -100,
                    left: 15,
                    right: 15,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row: Time and Action Icons
                        Row(
                          children: [
                            Text(
                              "${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _isMuted = !_isMuted;
                                  _controller.setVolume(_isMuted ? 0 : 1);
                                });
                              },
                              icon: Icon(
                                _isMuted ? Icons.volume_off : Icons.volume_up,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FullScreenVideoPlayer(
                                      controller: _controller,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.more_vert, color: Colors.white),
                          ],
                        ),

                        // Progress Slider
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white30,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _controller.value.position.inMilliseconds
                                .toDouble(),
                            max: _controller.value.duration.inMilliseconds
                                .toDouble(),
                            onChanged: (val) {
                              _controller.seekTo(
                                Duration(milliseconds: val.toInt()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
