import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/product_provider.dart';
import 'package:binetatour/core/utils/media_url_resolver.dart';
import 'package:binetatour/core/video/network_quality_estimator.dart';
import 'package:binetatour/core/video/reels_video_controller_pool.dart';
import 'package:binetatour/presentation/common/widgets/video_loading_indicator.dart';

class ProductVideoItem extends StatefulWidget {
  final int productId;
  final int? itemIndex;
  final String videoUrl;
  final String? fallbackUrl;
  final String? thumbnailUrl;
  final bool isMuted;
  final bool isActive;
  final List<String>? upcomingUrls;

  const ProductVideoItem({
    super.key,
    required this.productId,
    this.itemIndex,
    required this.videoUrl,
    this.fallbackUrl,
    this.thumbnailUrl,
    required this.isMuted,
    this.isActive = true,
    this.upcomingUrls,
  });

  @override
  State<ProductVideoItem> createState() => _ProductVideoItemState();
}

class _ProductVideoItemState extends State<ProductVideoItem> {
  ReelsPlayerSlot? _slot;
  final ValueNotifier<bool> _isManuallyPaused = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _showGraceSpinner = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _showMidStreamSpinner = ValueNotifier<bool>(false);
  VoidCallback? _slotListener;
  Timer? _stallWatchdogTimer;
  Timer? _gracePeriodTimer;
  Timer? _midStreamBufferingTimer;
  Duration _lastStallCheckPosition = Duration.zero;
  int _stallCount = 0;

  void _startGracePeriodTimer() {
    _gracePeriodTimer?.cancel();
    _showGraceSpinner.value = false;
    if (!widget.isActive) return;

    if (_slot?.hasFirstFrame.value == true) return;

    _gracePeriodTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || !widget.isActive) return;
      if (_slot?.hasFirstFrame.value != true) {
        _showGraceSpinner.value = true;
      }
    });
  }

  void _cancelGracePeriodTimer() {
    _gracePeriodTimer?.cancel();
    _gracePeriodTimer = null;
    if (_showGraceSpinner.value) {
      _showGraceSpinner.value = false;
    }
  }

  void _cancelMidStreamBufferingTimer() {
    _midStreamBufferingTimer?.cancel();
    _midStreamBufferingTimer = null;
    if (_showMidStreamSpinner.value) {
      _showMidStreamSpinner.value = false;
    }
  }

  // Global memoized aspect ratios by URL (prevents layout jump on swiping)
  static final Map<String, bool> _landscapeCache = {};

  bool _isLandscape = false;

  // Memoized URL computations (avoid re-computing on every build)
  late String _cachedVideoUrl;
  late String _cachedThumbnail;
  bool _hasTrackedView = false;

  // Static decorations (avoid allocating on every build)
  static const _playIconDecoration = BoxDecoration(
    color: Color(0x80000000), // Colors.black with 50% alpha
    shape: BoxShape.circle,
  );
  static const _darkPlaceholder = ColoredBox(color: Color(0xFF141414));

  void _startStallWatchdog(ReelsPlayerSlot slot) {
    _stallWatchdogTimer?.cancel();
    _stallCount = 0;
    _lastStallCheckPosition = slot.player.state.position;

    _stallWatchdogTimer = Timer.periodic(const Duration(milliseconds: 750), (
      timer,
    ) {
      if (!mounted ||
          !widget.isActive ||
          _isManuallyPaused.value ||
          slot.isCompleted.value ||
          ReelsVideoControllerPool.instance.isGloballyPaused) {
        return;
      }

      final currentPos = slot.player.state.position;
      final dur = slot.duration.value > Duration.zero
          ? slot.duration.value
          : slot.player.state.duration;
      final isPlayingState = slot.player.state.playing;
      final hasRendered = slot.hasFirstFrame.value;

      // 1. Completion detection: only trigger if actually at the very end of video
      final isNearEnd =
          dur > const Duration(seconds: 1) &&
          (currentPos >= dur - const Duration(milliseconds: 600) ||
              currentPos.inMilliseconds >= (dur.inMilliseconds * 0.98));
      if (isNearEnd) {
        slot.setCompleted(true);
        slot.setPlaying(false);
        slot.setBuffering(false);
        try {
          slot.player.pause().catchError((_) {});
        } catch (_) {}
        _stopStallWatchdog();
        return;
      }

      // 2. Decoder freeze vs network starvation handling:
      // Only check if video has rendered, claims to be playing, but position hasn't moved:
      if (hasRendered && isPlayingState && !slot.isBuffering.value) {
        if (currentPos == _lastStallCheckPosition &&
            currentPos > Duration.zero) {
          _stallCount++;
          // Stalled for >= 1.5 seconds at the exact same position while supposedly playing:
          if (_stallCount == 2) {
            if (Platform.isIOS) {
              debugPrint(
                '⚡️ [ProductVideoItem] iOS playback freeze detected at $currentPos. Auto-unfreezing...',
              );
              try {
                slot.player
                    .pause()
                    .then((_) {
                      if (mounted &&
                          widget.isActive &&
                          !_isManuallyPaused.value) {
                        try {
                          final isMuted =
                              ReelsVideoControllerPool.instance.isMuted;
                          (slot.player.platform as dynamic)?.setProperty(
                            'aid',
                            isMuted ? 'no' : 'auto',
                          );
                          slot.player.setVolume(isMuted ? 0.0 : 100.0);
                        } catch (_) {}
                        slot.player.play().catchError((_) {});
                      }
                    })
                    .catchError((_) {});
              } catch (_) {}
            } else {
              // On Android MediaCodec, this is a network buffer starvation:
              // Mark buffering so the UI shows the spinner and allows the buffer to fill
              // WITHOUT hammering the decoder with continuous pause/play resets!
              slot.setBuffering(true);
              NetworkQualityEstimator.instance.recordPlaybackStall();
            }
          } else if (_stallCount > 3) {
            // Persisting freeze/starvation: ensure buffering is shown and ABR dropped to 240p
            slot.setBuffering(true);
            NetworkQualityEstimator.instance.recordPlaybackStall();
          }
        } else {
          _stallCount = 0;
          _lastStallCheckPosition = currentPos;
        }
      } else {
        _stallCount = 0;
        _lastStallCheckPosition = currentPos;
      }
    });
  }

  void _stopStallWatchdog() {
    _stallWatchdogTimer?.cancel();
    _stallWatchdogTimer = null;
    _stallCount = 0;
  }

  void _attachSlotListener(ReelsPlayerSlot? newSlot) {
    _slotListener?.call();
    _slotListener = null;
    _stopStallWatchdog();

    if (newSlot != null) {
      void listener() {
        if (newSlot.isPlaying.value) {
          if (_isManuallyPaused.value) {
            _isManuallyPaused.value = false;
          }
        } else {
          // Auto-resume watchdog: If playback stopped unexpectedly while this item is active,
          // not manually paused by the user, and not genuinely completed:
          if (mounted &&
              widget.isActive &&
              !_isManuallyPaused.value &&
              !newSlot.isCompleted.value &&
              !ReelsVideoControllerPool.instance.isGloballyPaused) {
            final pos = newSlot.player.state.position;
            final dur = newSlot.duration.value > Duration.zero
                ? newSlot.duration.value
                : newSlot.player.state.duration;
            final isNearEnd =
                dur > const Duration(seconds: 1) &&
                (pos >= dur - const Duration(milliseconds: 600) ||
                    pos.inMilliseconds >= (dur.inMilliseconds * 0.98));
            if (isNearEnd) {
              newSlot.setCompleted(true);
              return;
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted &&
                  widget.isActive &&
                  !_isManuallyPaused.value &&
                  !newSlot.isCompleted.value &&
                  !newSlot.isPlaying.value &&
                  !ReelsVideoControllerPool.instance.isGloballyPaused) {
                try {
                  final isMuted = ReelsVideoControllerPool.instance.isMuted;
                  (newSlot.player.platform as dynamic)?.setProperty(
                    'aid',
                    isMuted ? 'no' : 'auto',
                  );
                  newSlot.player.setVolume(isMuted ? 0.0 : 100.0);
                } catch (_) {}
                newSlot.player.play().catchError((_) {});
              }
            });
          }
        }
      }

      newSlot.isPlaying.addListener(listener);

      void frameListener() {
        if (newSlot.hasFirstFrame.value) {
          _cancelGracePeriodTimer();
        }
      }

      newSlot.hasFirstFrame.addListener(frameListener);

      void bufferingListener() {
        if (!mounted || !widget.isActive) return;
        final isBuf = newSlot.isBuffering.value;
        final hasFrame = newSlot.hasFirstFrame.value;

        // Only show buffering spinner mid-stream if video was already playing and stall lasts > 450ms
        if (isBuf && hasFrame) {
          _midStreamBufferingTimer?.cancel();
          _midStreamBufferingTimer = Timer(
            const Duration(milliseconds: 450),
            () {
              if (mounted &&
                  widget.isActive &&
                  newSlot.isBuffering.value &&
                  newSlot.hasFirstFrame.value) {
                _showMidStreamSpinner.value = true;
              }
            },
          );
        } else if (!isBuf) {
          _cancelMidStreamBufferingTimer();
        }
      }

      newSlot.isBuffering.addListener(bufferingListener);

      _slotListener = () {
        newSlot.isPlaying.removeListener(listener);
        newSlot.hasFirstFrame.removeListener(frameListener);
        newSlot.isBuffering.removeListener(bufferingListener);
      };

      if (newSlot.hasFirstFrame.value) {
        _cancelGracePeriodTimer();
      } else if (widget.isActive) {
        _startGracePeriodTimer();
      }

      if (widget.isActive) {
        _startStallWatchdog(newSlot);
      }
    } else {
      _cancelGracePeriodTimer();
      _cancelMidStreamBufferingTimer();
    }
  }

  @override
  void initState() {
    super.initState();
    _computeCachedUrls();
    _checkInitialAspect();
    final itemIdx = widget.itemIndex ?? widget.productId;
    _slot = ReelsVideoControllerPool.instance.getSlotForIndex(
      itemIdx,
      _cachedVideoUrl,
    );
    _attachSlotListener(_slot);
    if (widget.isActive) {
      if (_slot == null ||
          ReelsVideoControllerPool.instance.activeProductIndex != itemIdx) {
        _activateSlot();
      } else {
        _slot!.setCompleted(false);
        if (!_slot!.player.state.playing) {
          try {
            _slot!.player.play().catchError((_) {});
          } catch (_) {}
        }
      }
    }
  }

  void _computeCachedUrls() {
    _cachedVideoUrl = _resolveVideoUrl();
    _cachedThumbnail = _computeThumbnail();
  }

  void _checkInitialAspect() {
    if (_cachedVideoUrl.isNotEmpty &&
        _landscapeCache.containsKey(_cachedVideoUrl)) {
      _isLandscape = _landscapeCache[_cachedVideoUrl]!;
      return;
    }
    if (_cachedThumbnail.isNotEmpty &&
        _landscapeCache.containsKey(_cachedThumbnail)) {
      _isLandscape = _landscapeCache[_cachedThumbnail]!;
      return;
    }
    if (_cachedThumbnail.isNotEmpty) {
      try {
        final img = NetworkImage(_cachedThumbnail);
        img
            .resolve(const ImageConfiguration())
            .addListener(
              ImageStreamListener((ImageInfo info, bool _) {
                if (!mounted) return;
                final w = info.image.width;
                final h = info.image.height;
                if (w > 0 && h > 0) {
                  final isLand = (w / h) > 1.15;
                  _landscapeCache[_cachedThumbnail] = isLand;
                  if (_cachedVideoUrl.isNotEmpty) {
                    _landscapeCache[_cachedVideoUrl] = isLand;
                  }
                  if (_isLandscape != isLand) {
                    setState(() => _isLandscape = isLand);
                  }
                }
              }),
            );
      } catch (_) {}
    }
  }

  String _resolveVideoUrl() {
    String url = widget.videoUrl.trim();
    if (url.isEmpty && widget.fallbackUrl != null) {
      url = widget.fallbackUrl!.trim();
    }
    return MediaUrlResolver.resolveUrl(url);
  }

  String _computeThumbnail() {
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.trim().isNotEmpty) {
      return widget.thumbnailUrl!.trim();
    }
    final fromVideo = MediaUrlResolver.extractThumbnailFromVideoUrl(
      _cachedVideoUrl,
    );
    if (fromVideo.isNotEmpty) {
      return fromVideo;
    }
    final vUrl = _cachedVideoUrl;
    if (vUrl.contains('cloudflarestream.com')) {
      if (vUrl.contains('/downloads/default.mp4')) {
        return vUrl.replaceAll(
          '/downloads/default.mp4',
          '/thumbnails/thumbnail.jpg?width=640',
        );
      }
      if (vUrl.contains('/manifest/video.m3u8')) {
        return vUrl.replaceAll(
          '/manifest/video.m3u8',
          '/thumbnails/thumbnail.jpg?width=640',
        );
      }
    }
    return '';
  }

  void _activateSlot() {
    if (_cachedVideoUrl.isEmpty) return;

    final itemIdx = widget.itemIndex ?? widget.productId;
    final existing = ReelsVideoControllerPool.instance.getSlotForIndex(
      itemIdx,
      _cachedVideoUrl,
    );
    if (existing != null &&
        ReelsVideoControllerPool.instance.activeProductIndex == itemIdx) {
      _slot = existing;
      _attachSlotListener(_slot);
      _slot!.setCompleted(false);
      if (_slot!.player.state.position > Duration.zero) {
        try {
          _slot!.player.seek(Duration.zero).catchError((_) {});
        } catch (_) {}
      }
      if (!existing.player.state.playing) {
        try {
          existing.player.play().catchError((_) {});
        } catch (_) {}
      }
    } else {
      _slot = ReelsVideoControllerPool.instance.activateVideo(
        itemIndex: itemIdx,
        url: _cachedVideoUrl,
        nextUrls: widget.upcomingUrls,
      );
      _attachSlotListener(_slot);
    }

    if (!_hasTrackedView) {
      _hasTrackedView = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ProductProvider>().trackVideoView(widget.productId);
        }
      });
    }
  }

  @override
  void didUpdateWidget(ProductVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldResolvedVideo = _cachedVideoUrl;
    _computeCachedUrls();
    final isVideoChanged = oldResolvedVideo != _cachedVideoUrl;
    final isIndexChanged = oldWidget.itemIndex != widget.itemIndex;

    // Only re-activate slot if VIDEO URL or ITEM INDEX actually changed.
    // Never restart video on thumbnail or other metadata updates to eliminate slight reload.
    if (isVideoChanged || isIndexChanged) {
      _isManuallyPaused.value = false;
      _checkInitialAspect();
      if (widget.isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.isActive) {
            _activateSlot();
            setState(() {});
          }
        });
      } else {
        _attachSlotListener(null);
        _slot = null;
        setState(() {});
      }
    } else if (oldWidget.isActive != widget.isActive) {
      _isManuallyPaused.value = false;
      if (widget.isActive) {
        final itemIdx = widget.itemIndex ?? widget.productId;
        _slot = ReelsVideoControllerPool.instance.getSlotForIndex(
          itemIdx,
          _cachedVideoUrl,
        );
        if (_slot == null) {
          _activateSlot();
        } else {
          _attachSlotListener(_slot);
          _slot!.setCompleted(false);
          if (_slot!.player.state.position >
              const Duration(milliseconds: 300)) {
            _slot!.player.seek(Duration.zero).catchError((_) {});
          }
          if (!_slot!.player.state.playing) {
            try {
              final isMuted = ReelsVideoControllerPool.instance.isMuted;
              (_slot!.player.platform as dynamic)?.setProperty(
                'aid',
                isMuted ? 'no' : 'auto',
              );
              _slot!.player.setVolume(isMuted ? 0.0 : 100.0);
              _slot!.player.play().catchError((_) {});
            } catch (_) {}
          }
          _startStallWatchdog(_slot!);
        }
        setState(() {});
      } else {
        _stopStallWatchdog();
        _attachSlotListener(null);
        try {
          _slot?.setCompleted(false);
          (_slot?.player.platform as dynamic)?.setProperty('aid', 'no');
          _slot?.player.pause().catchError((_) {});
          if (_slot != null &&
              _slot!.player.state.position >
                  const Duration(milliseconds: 300)) {
            _slot?.player.seek(Duration.zero).catchError((_) {});
          }
        } catch (_) {}
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _cancelGracePeriodTimer();
    _cancelMidStreamBufferingTimer();
    _stopStallWatchdog();
    _slotListener?.call();
    _slotListener = null;
    _isManuallyPaused.dispose();
    _showGraceSpinner.dispose();
    _showMidStreamSpinner.dispose();
    super.dispose();
  }

  bool _isReplaying = false;

  Future<void> _replayVideo(ReelsPlayerSlot slot) async {
    if (_isReplaying) return;
    _isReplaying = true;
    _stopStallWatchdog();

    slot.setCompleted(false);
    _isManuallyPaused.value = false;

    try {
      final isMuted = ReelsVideoControllerPool.instance.isMuted;
      (slot.player.platform as dynamic)?.setProperty(
        'aid',
        isMuted ? 'no' : 'auto',
      );
      slot.player.setVolume(isMuted ? 0.0 : 100.0);
    } catch (_) {}

    try {
      await slot.player.seek(Duration.zero);
    } catch (_) {}

    if (!mounted || !widget.isActive || _isManuallyPaused.value) {
      _isReplaying = false;
      return;
    }

    try {
      await slot.player.play();
    } catch (_) {
      try {
        final cleanUrl = MediaUrlResolver.resolveUrl(_cachedVideoUrl);
        if (cleanUrl.isNotEmpty) {
          await slot.player.open(Media(cleanUrl), play: true);
        }
      } catch (_) {}
    }

    _isReplaying = false;

    if (mounted && widget.isActive && !_isManuallyPaused.value) {
      _startStallWatchdog(slot);
    }
  }

  void _togglePlayPause(ReelsPlayerSlot slot) {
    if (slot.player.state.playing) {
      slot.player.pause().catchError((_) {});
      _isManuallyPaused.value = true;
      _stopStallWatchdog();
    } else {
      slot.player.play().catchError((_) {});
      _isManuallyPaused.value = false;
      _startStallWatchdog(slot);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = _slot;
    final isLandscapeListenable =
        slot?.isLandscape ?? ValueNotifier<bool>(_isLandscape);

    return ValueListenableBuilder<bool>(
      valueListenable: isLandscapeListenable,
      builder: (context, slotIsLandscape, _) {
        final isLandscape = _isLandscape || slotIsLandscape;
        if (slotIsLandscape && _cachedVideoUrl.isNotEmpty) {
          _landscapeCache[_cachedVideoUrl] = true;
        }

        // Portrait (tall 9:16) videos fill full-screen like TikTok.
        // Landscape & square videos fit width with ambient background so ZERO video content is cut off.
        final bool shouldCover = !isLandscape;
        final BoxFit currentFit = shouldCover ? BoxFit.cover : BoxFit.fitWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (slot != null) {
              if (slot.isCompleted.value) {
                _replayVideo(slot);
              } else {
                _togglePlayPause(slot);
              }
            }
          },
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 0. Ambient Blurred Background for Landscape/Horizontal Videos
                if (isLandscape && !shouldCover && _cachedThumbnail.isNotEmpty)
                  Positioned.fill(
                    child: ClipRect(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: 20.0,
                          sigmaY: 20.0,
                        ),
                        child: Image.network(
                          _cachedThumbnail,
                          fit: BoxFit.cover,
                          color: Colors.black.withValues(alpha: 0.55),
                          colorBlendMode: BlendMode.darken,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) =>
                              _darkPlaceholder,
                        ),
                      ),
                    ),
                  ),

                // 1. Live Video Surface — full screen cover for portrait, fitWidth for landscape
                if (slot != null)
                  RepaintBoundary(
                    child: SizedBox.expand(
                      child: Center(
                        child: Video(
                          controller: slot.videoController,
                          controls: NoVideoControls,
                          fit: currentFit,
                          fill: Colors.transparent,
                          alignment: Alignment.center,
                          width: shouldCover ? double.infinity : null,
                          height: shouldCover ? double.infinity : null,
                        ),
                      ),
                    ),
                  ),

                // 2. Poster Image — continuous AnimatedOpacity crossfade to video when first frame renders
                if (slot != null)
                  ValueListenableBuilder<bool>(
                    valueListenable: slot.hasFirstFrame,
                    child: _buildPoster(currentFit, shouldCover),
                    builder: (context, hasFrame, child) {
                      return IgnorePointer(
                        ignoring: hasFrame,
                        child: RepaintBoundary(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            opacity: hasFrame ? 0.0 : 1.0,
                            child: child,
                          ),
                        ),
                      );
                    },
                  )
                else
                  IgnorePointer(child: _buildPoster(currentFit, shouldCover)),

                // 3. Low internet / loading buffering indicator with grace period
                if (widget.isActive)
                  ValueListenableBuilder<bool>(
                    valueListenable: _isManuallyPaused,
                    builder: (context, isManuallyPaused, _) {
                      if (isManuallyPaused) return const SizedBox.shrink();
                      if (slot?.isCompleted.value == true) {
                        return const SizedBox.shrink();
                      }

                      return ListenableBuilder(
                        listenable: Listenable.merge([
                          _showGraceSpinner,
                          _showMidStreamSpinner,
                        ]),
                        builder: (context, _) {
                          final bool shouldShowLoading =
                              _showGraceSpinner.value ||
                              _showMidStreamSpinner.value;

                          return Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: shouldShowLoading
                                  ? const VideoLoadingIndicator()
                                  : const SizedBox.shrink(),
                            ),
                          );
                        },
                      );
                    },
                  ),

                // 4. Play/Replay icon overlay — shown when user manually paused OR when video ends
                if (slot != null)
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      slot.isPlaying,
                      slot.isCompleted,
                      _isManuallyPaused,
                    ]),
                    builder: (context, child) {
                      final isPlaying = slot.isPlaying.value;
                      final isCompleted = slot.isCompleted.value;
                      final isManuallyPaused = _isManuallyPaused.value;

                      // Never show during loading/buffering or when actively playing
                      if (isPlaying || (!isManuallyPaused && !isCompleted)) {
                        return const SizedBox.shrink();
                      }
                      return Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (isCompleted) {
                              _replayVideo(slot);
                            } else {
                              _togglePlayPause(slot);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: DecoratedBox(
                              decoration: _playIconDecoration,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Icon(
                                  isCompleted
                                      ? Icons.replay_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPoster(BoxFit fit, bool shouldCover) {
    if (_cachedThumbnail.isNotEmpty) {
      return SizedBox.expand(
        child: Center(
          child: Image.network(
            _cachedThumbnail,
            fit: fit,
            width: shouldCover ? double.infinity : null,
            height: shouldCover ? double.infinity : null,
            alignment: Alignment.center,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                return child;
              }
              return _darkPlaceholder;
            },
            errorBuilder: (context, error, stackTrace) => _darkPlaceholder,
          ),
        ),
      );
    }
    return _darkPlaceholder;
  }
}
