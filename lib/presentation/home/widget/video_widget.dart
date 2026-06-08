import 'dart:async';
import 'package:binetatour/presentation/home/widget/full_screen_player.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlaceholder extends StatefulWidget {
  final String link;
  final String? thumbnailUrl;

  const VideoPlaceholder({super.key, required this.link, this.thumbnailUrl});

  @override
  State<VideoPlaceholder> createState() => _VideoPlaceholderState();
}

class _VideoPlaceholderState extends State<VideoPlaceholder> {
  late final Player _player = Player();
  late final VideoController _videoController = VideoController(
    _player,
    configuration: const VideoControllerConfiguration(
      enableHardwareAcceleration: false,
    ),
  );

  bool _showControls = false;
  bool _isMuted = true;
  Timer? _hideTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    _player.setPlaylistMode(PlaylistMode.single);
    _player.setVolume(0.0); // Default muted

    _player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    _player.open(Media(widget.link));
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _player.dispose();
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

  // Formats Duration to mm:ss
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
                // 1. The Video Player (ALWAYS IN TREE so libmpv can attach to surface)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width:
                          _videoController.player.state.width?.toDouble() ??
                          16.0,
                      height:
                          _videoController.player.state.height?.toDouble() ??
                          9.0,
                      child: Video(
                        controller: _videoController,
                        controls: NoVideoControls,
                      ),
                    ),
                  ),
                ),

                // 2. Thumbnail / Loading State (On top, hides when playing starts)
                if (!_isPlaying)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: widget.thumbnailUrl != null
                          ? Image.network(
                              widget.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white38,
                                  size: 40,
                                ),
                              ),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                );
                              },
                            )
                          : const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
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
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Center Play/Pause Circle
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isPlaying ? _player.pause() : _player.play();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 45,
                        ),
                      ),
                    ),
                  ),
                ),

                // 5. Bottom Controls (Timer, Icons, Slider)
                if (_isPlaying || _position > Duration.zero)
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
                              "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
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
                                  _player.setVolume(_isMuted ? 0.0 : 100.0);
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
                                    builder: (context) =>
                                        FullScreenVideoPlayer(player: _player),
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
                            value: _position.inMilliseconds.toDouble().clamp(
                              0.0,
                              _duration.inMilliseconds.toDouble(),
                            ),
                            max: _duration.inMilliseconds.toDouble() > 0
                                ? _duration.inMilliseconds.toDouble()
                                : 1.0,
                            onChanged: (val) {
                              _player.seek(Duration(milliseconds: val.toInt()));
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
