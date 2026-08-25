import 'package:binetatour/core/base_url/base_url.dart';
import 'package:binetatour/core/video/feed_video_manager.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';
import 'package:binetatour/presentation/home/widget/full_screen_player.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';

class VideoPlaceholder extends StatefulWidget {
  final String link;
  final String? fallbackLink;
  final String? thumbnailUrl;

  const VideoPlaceholder({
    super.key,
    required this.link,
    this.fallbackLink,
    this.thumbnailUrl,
  });

  @override
  State<VideoPlaceholder> createState() => _VideoPlaceholderState();
}

class _VideoPlaceholderState extends State<VideoPlaceholder>
    with WidgetsBindingObserver {
  late final Player _player = Player(
    configuration: const PlayerConfiguration(
      bufferSize: 10 * 1024 * 1024,
      logLevel: MPVLogLevel.warn,
    ),
  );

  late final VideoController _videoController = VideoController(
    _player,
    configuration: const VideoControllerConfiguration(
      enableHardwareAcceleration: true,
    ),
  );

  final ValueNotifier<bool> _isMuted = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isBuffering = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _hasStartedPlaying = ValueNotifier<bool>(false);

  bool _isSeeking = false;
  double _dragValue = 0.0;
  bool _hasTriedFallback = false;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FeedVideoManager.instance.addListener(_onFeedManagerUpdate);
    _initializePlayer();
  }

  void _onFeedManagerUpdate() {
    if (!mounted) return;
    if (FeedVideoManager.instance.isGloballyPaused ||
        FeedVideoManager.instance.activeTabIndex != 0) {
      if (_isPlaying.value) {
        _player.pause();
      }
    } else if (_isVisible && !_isPlaying.value) {
      _player.play();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _player.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_isVisible &&
          !FeedVideoManager.instance.isGloballyPaused &&
          FeedVideoManager.instance.activeTabIndex == 0) {
        _player.play();
      }
    }
  }

  void _onVisibilityChanged(double visibleFraction) {
    _isVisible = visibleFraction > 0.25;
    if (!mounted) return;
    if (!_isVisible) {
      if (_isPlaying.value) {
        _player.pause();
      }
    } else {
      if (!FeedVideoManager.instance.isGloballyPaused &&
          FeedVideoManager.instance.activeTabIndex == 0) {
        _player.play();
      }
    }
  }

  void _openTargetVideo(String targetUrl) {
    if (targetUrl.trim().isEmpty) return;
    final cachedPath = VideoCacheManager.instance.getCachedFilePath(targetUrl);
    final playPath = cachedPath ?? targetUrl;
    _player.open(Media(playPath));
    if (cachedPath == null && targetUrl.startsWith('http')) {
      VideoCacheManager.instance.preCacheVideo(targetUrl);
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link != widget.link) {
      _hasTriedFallback = false;
      _hasStartedPlaying.value = false;
      _isBuffering.value = true;
      _openTargetVideo(_resolvedVideoUrl);
    }
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
    _player.setPlaylistMode(PlaylistMode.loop);
    _player.setVolume(0.0); // Default muted

    _player.stream.playing.listen((playing) {
      if (mounted) {
        _isPlaying.value = playing;
      }
    });

    _player.stream.position.listen((pos) {
      if (mounted && pos > Duration.zero) {
        _hasStartedPlaying.value = true;
        _isBuffering.value = false;
      }
    });

    _player.stream.buffering.listen((buffering) {
      if (mounted) {
        if (_hasStartedPlaying.value) {
          _isBuffering.value = buffering;
        } else {
          _isBuffering.value = true;
        }
      }
    });

    _player.stream.error.listen((error) {
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('audio device') || errorStr.contains('no sound')) {
        return; // Ignore harmless audio device warning for muted video preview
      }
      debugPrint("Video player error: $error");
      _handleFallback();
    });

    _openTargetVideo(_resolvedVideoUrl);
  }

  void _handleFallback() {
    if (!_hasTriedFallback &&
        widget.fallbackLink != null &&
        widget.fallbackLink!.trim().isNotEmpty &&
        widget.fallbackLink != widget.link) {
      _hasTriedFallback = true;
      String fallback = widget.fallbackLink!;
      if (!fallback.startsWith('http')) {
        final base = BaseUrl.baseUrl;
        fallback = fallback.startsWith('/')
            ? '$base$fallback'
            : '$base/$fallback';
      }
      debugPrint("Playback failed, falling back to: $fallback");
      _openTargetVideo(fallback);
    }
  }

  /// Tap on Video Body:
  /// - Toggle play/pause without affecting volume/mute state.
  void _handleVideoTap() {
    if (_isPlaying.value) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FeedVideoManager.instance.removeListener(_onFeedManagerUpdate);
    _player.dispose();
    _isMuted.dispose();
    _isPlaying.dispose();
    _isBuffering.dispose();
    _hasStartedPlaying.dispose();
    super.dispose();
  }

  Widget _buildDefaultPlaceholder({required bool isLoading}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5EE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF1E6),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF6900),
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Chargement de la vidéo...",
                style: TextStyle(
                  color: Color(0xFFE8500A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF1E6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFFE8500A),
                  size: 36,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Formats Duration to m:ss
  String _formatDuration(Duration duration) {
    if (duration < Duration.zero) return "0:00";
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Widget _buildGlassIconButton({
    required Widget child,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOptionsButton() {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 36,
        height: 36,
        child: PopupMenuButton<String>(
          color: const Color(0xFF1E1E1E),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 155),
          child: const Center(
            child: Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
          ),
          onSelected: (value) {
            if (value == 'play_pause') {
              _isPlaying.value ? _player.pause() : _player.play();
            } else if (value.startsWith('speed_')) {
              final speed =
                  double.tryParse(value.replaceFirst('speed_', '')) ?? 1.0;
              _player.setRate(speed);
            }
          },
          itemBuilder: (context) {
            final currentRate = _player.state.rate;
            return [
              PopupMenuItem<String>(
                value: 'play_pause',
                height: 40,
                child: Row(
                  children: [
                    Icon(
                      _isPlaying.value
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isPlaying.value ? "Mettre en pause" : "Lire la vidéo",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem<String>(
                enabled: false,
                height: 28,
                child: Text(
                  "Vitesse de lecture",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...[0.75, 1.0, 1.25, 1.5, 2.0].map((rate) {
                final isSelected = (currentRate - rate).abs() < 0.05;
                return PopupMenuItem<String>(
                  value: 'speed_$rate',
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        rate == 1.0 ? "Normale (1.0x)" : "${rate}x",
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFE8500A)
                              : Colors.white,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_rounded,
                          color: Color(0xFFE8500A),
                          size: 16,
                        ),
                    ],
                  ),
                );
              }),
            ];
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey('banner_video_${widget.link}'),
      onVisibilityChanged: (info) => _onVisibilityChanged(info.visibleFraction),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: const Color(0xFFFFF5EE),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. The Video Player Surface
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleVideoTap,
                child: SizedBox.expand(
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
              ),

              // 2. Thumbnail / Loading State (Fades out when video playback actually begins)
              Positioned.fill(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _hasStartedPlaying,
                  builder: (context, hasStartedPlaying, _) {
                    return AnimatedOpacity(
                      opacity: hasStartedPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: hasStartedPlaying,
                        child: Container(
                          color: const Color(0xFFFFF5EE),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_resolvedThumbnailUrl.isNotEmpty)
                                Image.network(
                                  _resolvedThumbnailUrl,
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
                                      _buildDefaultPlaceholder(isLoading: true),
                                )
                              else
                                _buildDefaultPlaceholder(isLoading: true),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 3. Permanent Bottom Gradient for high visibility and contrast
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 85,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Center Play Indicator when Paused
              ValueListenableBuilder<bool>(
                valueListenable: _isPlaying,
                builder: (context, isPlaying, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _hasStartedPlaying,
                    builder: (context, hasStarted, _) {
                      if (!isPlaying && hasStarted) {
                        return Center(
                          child: GestureDetector(
                            onTap: () => _player.play(),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),

              // 5. Fixed Bottom Controls (Exact Match with Screenshot: Timestamp, Fullscreen, Mute/Unmute, 3-dots, Progress Bar)
              Positioned(
                left: 10,
                right: 10,
                bottom: 4,
                child: StreamBuilder<Duration>(
                  stream: _player.stream.position,
                  builder: (context, snapshot) {
                    final pos = snapshot.data ?? _player.state.position;
                    final dur = _player.state.duration;

                    final double currentMs = _isSeeking
                        ? _dragValue
                        : pos.inMilliseconds.toDouble();
                    final double maxMs = dur.inMilliseconds.toDouble() > 0
                        ? dur.inMilliseconds.toDouble()
                        : 1.0;
                    final double clampedMs = currentMs.clamp(0.0, maxMs);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row: Time and 3 Action Icons (Fullscreen, Sound, 3-Dots)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Current Time / Duration (e.g. 1:48 / 4:32)
                              Text(
                                "${_formatDuration(_isSeeking ? Duration(milliseconds: clampedMs.toInt()) : pos)} / ${_formatDuration(dur)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 4,
                                      color: Colors.black87,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),

                              // 1. Fullscreen Button (Crop free rounded)
                              _buildGlassIconButton(
                                child: const Icon(
                                  Icons.crop_free_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onTap: () {
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
                              ),
                              const SizedBox(width: 8),

                              // 2. Sound / Volume Button (Mute / Unmute)
                              ValueListenableBuilder<bool>(
                                valueListenable: _isMuted,
                                builder: (context, isMuted, _) {
                                  return _buildGlassIconButton(
                                    child: Icon(
                                      isMuted
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onTap: () {
                                      final newMuted = !isMuted;
                                      _isMuted.value = newMuted;
                                      _player.setVolume(newMuted ? 0.0 : 100.0);
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 8),

                              // 3. More options (3-dots)
                              _buildMoreOptionsButton(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Progress Seek Line at bottom (Clean white line as in screenshot)
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.0,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 0.0,
                              disabledThumbRadius: 0.0,
                              pressedElevation: 0.0,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 8.0,
                            ),
                            trackShape: const RectangularSliderTrackShape(),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withValues(
                              alpha: 0.35,
                            ),
                            thumbColor: Colors.white,
                          ),
                          child: SizedBox(
                            height: 14,
                            child: Slider(
                              value: clampedMs,
                              max: maxMs,
                              onChangeStart: (val) {
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
                        ),
                      ],
                    );
                  },
                ),
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
                              strokeWidth: 3,
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
    );
  }
}
