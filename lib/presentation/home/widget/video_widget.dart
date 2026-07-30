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

class _VideoPlaceholderState extends State<VideoPlaceholder> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late final Player _player = Player();
  late final VideoController _videoController = VideoController(
    _player,
    configuration: const VideoControllerConfiguration(
      enableHardwareAcceleration: false,
    ),
  );

  final ValueNotifier<bool> _showControls = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isMuted = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isBuffering = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _hasStartedPlaying = ValueNotifier<bool>(false);

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _initializePlayer();
  }

  void _initializePlayer() {
    _player.setPlaylistMode(PlaylistMode.single);
    _player.setVolume(0.0); // Default muted

    _player.stream.playing.listen((playing) {
      _isPlaying.value = playing;
      _updateStartedPlayingState();
    });

    _player.stream.buffering.listen((buffering) {
      _isBuffering.value = buffering;
      _updateStartedPlayingState();
    });

    _player.open(Media(widget.link));
  }

  void _updateStartedPlayingState() {
    if (_isPlaying.value && !_isBuffering.value) {
      _hasStartedPlaying.value = true;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _player.dispose();
    _showControls.dispose();
    _isMuted.dispose();
    _isPlaying.dispose();
    _isBuffering.dispose();
    _hasStartedPlaying.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-2.0 + _shimmerController.value * 4.0, -1.0),
              end: Alignment(-1.0 + _shimmerController.value * 4.0, 1.0),
              colors: [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultPlaceholder({required bool isLoading}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[900]!,
            Colors.grey[850]!,
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(
                color: Color(0xFFFF6900),
              )
            : const Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white24,
                size: 64,
              ),
      ),
    );
  }

  // Logic to show controls on click/hover and hide after 3 seconds
  void _toggleControls() {
    _showControls.value = !_showControls.value;

    _hideTimer?.cancel();
    if (_showControls.value) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        _showControls.value = false;
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
      onEnter: (_) => _showControls.value = true,
      onExit: (_) => _showControls.value = false,
      child: GestureDetector(
        onTap: () {
          _isPlaying.value ? _player.pause() : _player.play();
          _toggleControls();
        },
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

                // 2. Thumbnail / Loading State (On top, hides when playing starts and buffering ends)
                ValueListenableBuilder<bool>(
                  valueListenable: _hasStartedPlaying,
                  builder: (context, hasStartedPlaying, _) {
                    if (!hasStartedPlaying) {
                      return Positioned.fill(
                        child: Container(
                          color: Colors.black,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (widget.thumbnailUrl != null && widget.thumbnailUrl!.trim().isNotEmpty)
                                Image.network(
                                  widget.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return _buildDefaultPlaceholder(isLoading: true);
                                  },
                                  errorBuilder: (_, _, _) => _buildDefaultPlaceholder(isLoading: false),
                                )
                              else
                                _buildDefaultPlaceholder(isLoading: false),
                              ValueListenableBuilder<bool>(
                                valueListenable: _isBuffering,
                                builder: (context, isBuffering, _) {
                                  if (isBuffering) {
                                    return Stack(
                                      children: [
                                        _buildShimmer(),
                                        const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFFF6900),
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // 3. Dark Gradient Overlay for readability
                ValueListenableBuilder<bool>(
                  valueListenable: _showControls,
                  builder: (context, showControls, _) {
                    return AnimatedOpacity(
                      opacity: showControls ? 1.0 : 0.0,
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
                    );
                  },
                ),

                // 4. Center Play/Pause Circle
                ValueListenableBuilder<bool>(
                  valueListenable: _showControls,
                  builder: (context, showControls, _) {
                    return AnimatedOpacity(
                      opacity: showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Center(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _isPlaying,
                          builder: (context, isPlaying, _) {
                            return GestureDetector(
                              onTap: () {
                                isPlaying ? _player.pause() : _player.play();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 45,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),

                // 5. Bottom Controls (Timer, Icons, Slider)
                ValueListenableBuilder<bool>(
                  valueListenable: _isPlaying,
                  builder: (context, isPlaying, _) {
                    if (isPlaying || _player.state.position > Duration.zero) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _showControls,
                        builder: (context, showControls, _) {
                          return AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            bottom: showControls ? 10 : -100,
                            left: 15,
                            right: 15,
                            child: StreamBuilder<Duration>(
                              stream: _player.stream.position,
                              builder: (context, snapshot) {
                                final pos =
                                    snapshot.data ?? _player.state.position;
                                final dur = _player.state.duration;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Row: Time and Action Icons
                                    Row(
                                      children: [
                                        Text(
                                          "${_formatDuration(pos)} / ${_formatDuration(dur)}",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        ValueListenableBuilder<bool>(
                                          valueListenable: _isMuted,
                                          builder: (context, isMuted, _) {
                                            return IconButton(
                                              onPressed: () {
                                                _isMuted.value = !isMuted;
                                                _player.setVolume(
                                                  _isMuted.value ? 0.0 : 100.0,
                                                );
                                              },
                                              icon: Icon(
                                                isMuted
                                                    ? Icons.volume_off
                                                    : Icons.volume_up,
                                                color: Colors.white,
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    FullScreenVideoPlayer(
                                                      player: _player,
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
                                        const Icon(
                                          Icons.more_vert,
                                          color: Colors.white,
                                        ),
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
                                        value: pos.inMilliseconds
                                            .toDouble()
                                            .clamp(
                                              0.0,
                                              dur.inMilliseconds.toDouble(),
                                            ),
                                        max: dur.inMilliseconds.toDouble() > 0
                                            ? dur.inMilliseconds.toDouble()
                                            : 1.0,
                                        onChanged: (val) {
                                          _player.seek(
                                            Duration(milliseconds: val.toInt()),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // 6. Buffering Indicator during active playback
                ValueListenableBuilder<bool>(
                  valueListenable: _hasStartedPlaying,
                  builder: (context, hasStartedPlaying, _) {
                    if (hasStartedPlaying) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _isBuffering,
                        builder: (context, isBuffering, _) {
                          if (isBuffering) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFF6900),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
