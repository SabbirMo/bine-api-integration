import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:binetatour/core/video/smart_video_controller.dart';

/// Reusable video player widget supporting Cloudflare Stream HLS with adaptive bitrate,
/// automatic buffering indicators, thumbnail placeholders, and interactive touch controls.
class SmartVideoPlayerWidget extends StatefulWidget {
  final SmartVideoController controller;
  final String? title;
  final bool showControls;
  final bool autoHideControls;
  final BoxFit fit;
  final VoidCallback? onBack;
  final VoidCallback? onFullscreenToggle;
  final bool isFullscreen;

  const SmartVideoPlayerWidget({
    super.key,
    required this.controller,
    this.title,
    this.showControls = true,
    this.autoHideControls = true,
    this.fit = BoxFit.contain,
    this.onBack,
    this.onFullscreenToggle,
    this.isFullscreen = false,
  });

  @override
  State<SmartVideoPlayerWidget> createState() => _SmartVideoPlayerWidgetState();
}

class _SmartVideoPlayerWidgetState extends State<SmartVideoPlayerWidget>
    with SingleTickerProviderStateMixin {
  bool _areControlsVisible = true;
  Timer? _controlsTimer;

  bool _isSeeking = false;
  double _dragValue = 0.0;

  // Double tap seek indicators
  int _seekOverlayType = 0; // -1 = rewind 10s, +1 = forward 10s, 0 = hidden
  Timer? _seekOverlayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.autoHideControls) {
      _startControlsTimer();
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _seekOverlayTimer?.cancel();
    super.dispose();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (!widget.autoHideControls) return;
    _controlsTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && widget.controller.isPlaying.value) {
        setState(() {
          _areControlsVisible = false;
        });
      }
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _areControlsVisible = !_areControlsVisible;
    });
    if (_areControlsVisible) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  void _triggerSeekAnimation(int direction) {
    setState(() {
      _seekOverlayType = direction;
    });
    _seekOverlayTimer?.cancel();
    _seekOverlayTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _seekOverlayType = 0;
        });
      }
    });
  }

  void _seekRelative(Duration delta) {
    final current = widget.controller.position.value;
    final total = widget.controller.duration.value;
    final target = current + delta;
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(0, total.inMilliseconds),
    );
    widget.controller.seek(clamped);
    _triggerSeekAnimation(delta.isNegative ? -1 : 1);
  }

  String _formatDuration(Duration duration) {
    if (duration < Duration.zero) return '0:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:${minutes.padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showSpeedModal() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ValueListenableBuilder<double>(
            valueListenable: widget.controller.playbackRate,
            builder: (context, activeRate, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text(
                      'Vitesse de lecture',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  ...speeds.map((rate) {
                    final isSelected = (activeRate - rate).abs() < 0.05;
                    return ListTile(
                      dense: true,
                      title: Text(
                        rate == 1.0 ? 'Normale (1.0x)' : '${rate}x',
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFFF8A00)
                              : Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFFFF8A00),
                              size: 20,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.controller.setRate(rate);
                      },
                    );
                  }),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          // 1. Video Surface
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControlsVisibility,
            onDoubleTapDown: (details) {
              final screenWidth = MediaQuery.of(context).size.width;
              if (details.localPosition.dx < screenWidth / 2) {
                _seekRelative(const Duration(seconds: -10));
              } else {
                _seekRelative(const Duration(seconds: 10));
              }
            },
            child: Center(
              child: Video(
                controller: widget.controller.videoController,
                controls: NoVideoControls,
                fit: widget.fit,
              ),
            ),
          ),

          // 2. Video Captured Frame / Placeholder (Active while video is initializing)
          ValueListenableBuilder<bool>(
            valueListenable: widget.controller.hasStartedPlaying,
            builder: (context, hasStarted, _) {
              return AnimatedOpacity(
                opacity: hasStarted ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: hasStarted,
                  child: Container(
                    color: const Color(0xFF141414),
                    child: Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      children: [
                        ValueListenableBuilder<Uint8List?>(
                          valueListenable: widget.controller.capturedFrame,
                          builder: (context, frameBytes, _) {
                            if (frameBytes != null && frameBytes.isNotEmpty) {
                              return Image.memory(
                                frameBytes,
                                fit: widget.fit,
                                gaplessPlayback: true,
                              );
                            }
                            return const Center(
                              child: Icon(
                                Icons.movie_rounded,
                                color: Colors.white24,
                                size: 54,
                              ),
                            );
                          },
                        ),
                        Container(
                          color: Colors.black38,
                          child: const Center(
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: CircularProgressIndicator(
                                color: Color(0xFFFF8A00),
                                strokeWidth: 3.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // 3. Double-Tap Seek Ripples & Feedback
          if (_seekOverlayType != 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black26,
                  child: Align(
                    alignment: _seekOverlayType == -1
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _seekOverlayType == -1
                                ? Icons.fast_rewind_rounded
                                : Icons.fast_forward_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _seekOverlayType == -1 ? '-10s' : '+10s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 4. Buffering Spinner mid-playback
          ValueListenableBuilder<bool>(
            valueListenable: widget.controller.hasStartedPlaying,
            builder: (context, hasStarted, _) {
              if (!hasStarted) return const SizedBox.shrink();
              return ValueListenableBuilder<bool>(
                valueListenable: widget.controller.isBuffering,
                builder: (context, isBuffering, _) {
                  if (isBuffering) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF8A00),
                          strokeWidth: 3.5,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),

          // 5. Reconnection & Error Banner
          ValueListenableBuilder<String?>(
            valueListenable: widget.controller.errorMessage,
            builder: (context, errorMsg, _) {
              if (errorMsg == null) return const SizedBox.shrink();
              return Positioned(
                top: 70,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          errorMsg,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          backgroundColor: Colors.white24,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: widget.controller.retry,
                        child: const Text(
                          'Réessayer',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 6. Interactive Video Controls Overlay
          if (widget.showControls)
            AnimatedOpacity(
              opacity: _areControlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_areControlsVisible,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient Shadow Overlays for readability
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.75),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Top Bar (Back button, Title, Quality Picker, Speed Picker)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 6,
                      left: 10,
                      right: 10,
                      child: Row(
                        children: [
                          if (widget.onBack != null)
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: widget.onBack,
                            ),
                          if (widget.title != null) ...[
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.title!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else
                            const Spacer(),

                          // Auto Adaptive Bitrate Live Indicator Badge
                          ValueListenableBuilder<String>(
                            valueListenable:
                                widget.controller.currentResolution,
                            builder: (context, res, _) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFF8A00,
                                    ).withValues(alpha: 0.5),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Color(0xFFFF8A00),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      res == 'Detecting...'
                                          ? 'Auto'
                                          : 'Auto ($res)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),

                          // Speed Selector Button
                          ValueListenableBuilder<double>(
                            valueListenable: widget.controller.playbackRate,
                            builder: (context, rate, _) {
                              return TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  backgroundColor: Colors.black.withValues(
                                    alpha: 0.45,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  _startControlsTimer();
                                  _showSpeedModal();
                                },
                                child: Text(
                                  rate == 1.0 ? '1.0x' : '${rate}x',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Center Play/Pause/Replay Action
                    Center(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: widget.controller.isPlaying,
                        builder: (context, isPlaying, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: widget.controller.isCompleted,
                            builder: (context, isCompleted, _) {
                              final IconData icon = isCompleted
                                  ? Icons.replay_rounded
                                  : (isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded);

                              return GestureDetector(
                                onTap: () {
                                  _startControlsTimer();
                                  widget.controller.togglePlayPause();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // Bottom Bar (Timestamps, Scrub Slider, Mute, Fullscreen)
                    Positioned(
                      bottom: 8,
                      left: 14,
                      right: 14,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Time, Mute & Fullscreen Row
                          Row(
                            children: [
                              ValueListenableBuilder<Duration>(
                                valueListenable: widget.controller.position,
                                builder: (context, pos, _) {
                                  return ValueListenableBuilder<Duration>(
                                    valueListenable: widget.controller.duration,
                                    builder: (context, dur, _) {
                                      final current = _isSeeking
                                          ? Duration(
                                              milliseconds: _dragValue.toInt(),
                                            )
                                          : pos;
                                      return Text(
                                        '${_formatDuration(current)} / ${_formatDuration(dur)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black87,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              const Spacer(),

                              // Mute/Unmute Toggle
                              ValueListenableBuilder<bool>(
                                valueListenable: widget.controller.isMuted,
                                builder: (context, isMuted, _) {
                                  return IconButton(
                                    icon: Icon(
                                      isMuted
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      _startControlsTimer();
                                      widget.controller.toggleMute();
                                    },
                                  );
                                },
                              ),

                              // Fullscreen Toggle
                              if (widget.onFullscreenToggle != null)
                                IconButton(
                                  icon: Icon(
                                    widget.isFullscreen
                                        ? Icons.fullscreen_exit_rounded
                                        : Icons.fullscreen_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    _startControlsTimer();
                                    widget.onFullscreenToggle!();
                                  },
                                ),
                            ],
                          ),

                          // Scrub Slider with Buffer Background
                          ValueListenableBuilder<Duration>(
                            valueListenable: widget.controller.position,
                            builder: (context, pos, _) {
                              return ValueListenableBuilder<Duration>(
                                valueListenable: widget.controller.duration,
                                builder: (context, dur, _) {
                                  final double maxMs = dur.inMilliseconds > 0
                                      ? dur.inMilliseconds.toDouble()
                                      : 1.0;
                                  final double currentMs = _isSeeking
                                      ? _dragValue
                                      : pos.inMilliseconds.toDouble().clamp(
                                          0.0,
                                          maxMs,
                                        );

                                  return SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3.5,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6.0,
                                        pressedElevation: 3.0,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                            overlayRadius: 14.0,
                                          ),
                                      activeTrackColor: const Color(0xFFFF8A00),
                                      inactiveTrackColor: Colors.white30,
                                      thumbColor: const Color(0xFFFF8A00),
                                    ),
                                    child: Slider(
                                      value: currentMs.clamp(0.0, maxMs),
                                      max: maxMs,
                                      onChangeStart: (val) {
                                        _controlsTimer?.cancel();
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
                                        widget.controller.seek(
                                          Duration(milliseconds: val.toInt()),
                                        );
                                        setState(() {
                                          _isSeeking = false;
                                        });
                                        _startControlsTimer();
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Standalone Full-screen Video Player Page with automatic orientation management
/// and smooth Cloudflare Stream HLS playback.
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String? title;
  final SmartVideoConfig? config;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.title,
    this.config,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  late final SmartVideoController _controller;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = SmartVideoController(
      originalUrl: widget.videoUrl,
      config: widget.config ?? const SmartVideoConfig(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _controller.pause();
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: !_isFullscreen,
        bottom: !_isFullscreen,
        left: false,
        right: false,
        child: SmartVideoPlayerWidget(
          controller: _controller,
          title: widget.title,
          isFullscreen: _isFullscreen,
          onFullscreenToggle: _toggleFullscreen,
          onBack: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
