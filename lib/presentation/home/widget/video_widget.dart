import 'dart:async';
import 'package:binetatour/core/base_url/base_url.dart';
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
      enableHardwareAcceleration: true,
    ),
  );

  final ValueNotifier<bool> _showControls = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isMuted = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isBuffering = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _hasStartedPlaying = ValueNotifier<bool>(false);

  Timer? _hideTimer;
  bool _isSeeking = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  String get _resolvedThumbnailUrl {
    String url = widget.thumbnailUrl ?? '';
    if (url.isNotEmpty && !url.startsWith('http')) {
      final base = BaseUrl.baseUrl;
      if (url.startsWith('/')) {
        url = '$base$url';
      } else {
        url = '$base/$url';
      }
    }
    return url;
  }

  String get _resolvedVideoUrl {
    String url = widget.link;
    if (url.isNotEmpty && !url.startsWith('http')) {
      final base = BaseUrl.baseUrl;
      if (url.startsWith('/')) {
        url = '$base$url';
      } else {
        url = '$base/$url';
      }
    }
    return url;
  }

  void _initializePlayer() {
    _player.setPlaylistMode(PlaylistMode.single);
    _player.setVolume(0.0); // Default muted

    _player.stream.playing.listen((playing) {
      if (mounted) {
        _isPlaying.value = playing;
        _updateStartedPlayingState();
      }
    });

    _player.stream.buffering.listen((buffering) {
      if (mounted) {
        _isBuffering.value = buffering;
        _updateStartedPlayingState();
      }
    });

    _player.open(Media(_resolvedVideoUrl));
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
    super.dispose();
  }

  Widget _buildDefaultPlaceholder({required bool isLoading}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[900]!, Colors.grey[850]!, Colors.black],
        ),
      ),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(color: Color(0xFFFF6900))
            : const Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white24,
                size: 64,
              ),
      ),
    );
  }

  void _toggleControls() {
    _showControls.value = !_showControls.value;
    if (_showControls.value) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_showControls.value && !_isSeeking) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !_isSeeking) {
          _showControls.value = false;
        }
      });
    }
  }

  // Formats Duration to m:ss
  String _formatDuration(Duration duration) {
    if (duration < Duration.zero) return "0:00";
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        _showControls.value = true;
        _startHideTimer();
      },
      onExit: (_) {
        _hideTimer?.cancel();
        _showControls.value = false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Tapping the video toggles overlay controls visibility (show/hide)
          _toggleControls();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. The Video Player (ALWAYS IN TREE so surface attaches)
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

                // 2. Thumbnail / Loading State (Only before first play starts)
                ValueListenableBuilder<bool>(
                  valueListenable: _hasStartedPlaying,
                  builder: (context, hasStartedPlaying, _) {
                    if (!hasStartedPlaying) {
                      final thumb = _resolvedThumbnailUrl;
                      return Positioned.fill(
                        child: Container(
                          color: Colors.black,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (thumb.isNotEmpty)
                                Image.network(
                                  thumb,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return _buildDefaultPlaceholder(
                                          isLoading: true,
                                        );
                                      },
                                  errorBuilder: (_, _, _) =>
                                      _buildDefaultPlaceholder(
                                        isLoading: false,
                                      ),
                                )
                              else
                                _buildDefaultPlaceholder(isLoading: false),
                              ValueListenableBuilder<bool>(
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
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // 3. Dark Gradient Overlay for readability when controls are active
                ValueListenableBuilder<bool>(
                  valueListenable: _showControls,
                  builder: (context, showControls, _) {
                    return AnimatedOpacity(
                      opacity: showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: IgnorePointer(
                        ignoring: !showControls,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.4),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.75),
                              ],
                            ),
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
                      duration: const Duration(milliseconds: 250),
                      child: IgnorePointer(
                        ignoring: !showControls,
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
                                    size: 44,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 5. Bottom Controls (Timestamp, Mute, Fullscreen, Seek Slider)
                ValueListenableBuilder<bool>(
                  valueListenable: _showControls,
                  builder: (context, showControls, _) {
                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      bottom: showControls ? 6 : -120,
                      left: 12,
                      right: 12,
                      child: IgnorePointer(
                        ignoring: !showControls,
                        child: StreamBuilder<Duration>(
                          stream: _player.stream.position,
                          builder: (context, snapshot) {
                            final pos = snapshot.data ?? _player.state.position;
                            final dur = _player.state.duration;

                            final double currentMs = _isSeeking
                                ? _dragValue
                                : pos.inMilliseconds.toDouble();
                            final double maxMs =
                                dur.inMilliseconds.toDouble() > 0
                                ? dur.inMilliseconds.toDouble()
                                : 1.0;
                            final double clampedMs = currentMs.clamp(
                              0.0,
                              maxMs,
                            );

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Row: Time and Action Icons
                                Row(
                                  children: [
                                    const SizedBox(width: 4),
                                    Text(
                                      "${_formatDuration(_isSeeking ? Duration(milliseconds: clampedMs.toInt()) : pos)} / ${_formatDuration(dur)}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 4,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    ValueListenableBuilder<bool>(
                                      valueListenable: _isMuted,
                                      builder: (context, isMuted, _) {
                                        return IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(6),
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
                                            size: 22,
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(6),
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
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.more_vert,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ],
                                ),

                                // Progress Seek Slider
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 12,
                                    ),
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white.withValues(
                                      alpha: 0.35,
                                    ),
                                    thumbColor: Colors.white,
                                  ),
                                  child: Slider(
                                    value: clampedMs,
                                    max: maxMs,
                                    onChangeStart: (val) {
                                      _hideTimer?.cancel();
                                      setState(() {
                                        _isSeeking = true;
                                        _dragValue = val;
                                      });
                                    },
                                    onChanged: (val) {
                                      setState(() {
                                        _dragValue = val;
                                      });
                                    },
                                    onChangeEnd: (val) {
                                      _player.seek(
                                        Duration(milliseconds: val.toInt()),
                                      );
                                      setState(() {
                                        _isSeeking = false;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
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
