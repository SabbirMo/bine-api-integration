import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/product_provider.dart';
import 'package:binetatour/core/utils/media_url_resolver.dart';
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
  VoidCallback? _slotListener;

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
  static const _blackContainer = ColoredBox(color: Colors.black);

  void _attachSlotListener(ReelsPlayerSlot? newSlot) {
    _slotListener?.call();
    _slotListener = null;
    if (newSlot != null) {
      void listener() {
        if (newSlot.isPlaying.value && _isManuallyPaused.value) {
          _isManuallyPaused.value = false;
        }
      }

      newSlot.isPlaying.addListener(listener);
      _slotListener = () => newSlot.isPlaying.removeListener(listener);
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
            if (_slot!.player.state.position >
                const Duration(milliseconds: 300)) {
              _slot!.player.seek(Duration.zero).catchError((_) {});
            }
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
      if (!existing.player.state.playing) {
        try {
          if (existing.player.state.position >
              const Duration(milliseconds: 300)) {
            existing.player.seek(Duration.zero).catchError((_) {});
          }
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
          if (!_slot!.player.state.playing) {
            try {
              if (_slot!.player.state.position >
                  const Duration(milliseconds: 300)) {
                _slot!.player.seek(Duration.zero).catchError((_) {});
              }
              _slot!.player.play().catchError((_) {});
            } catch (_) {}
          }
        }
        setState(() {});
      } else {
        _attachSlotListener(null);
        try {
          _slot?.setCompleted(false);
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
    _slotListener?.call();
    _slotListener = null;
    _isManuallyPaused.dispose();
    super.dispose();
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
                slot.setCompleted(false);
                _isManuallyPaused.value = false;
                slot.player.seek(Duration.zero).catchError((_) {});
                slot.player.play().catchError((_) {});
              } else if (slot.player.state.playing) {
                slot.player.pause().catchError((_) {});
                _isManuallyPaused.value = true;
              } else {
                slot.player.play().catchError((_) {});
                _isManuallyPaused.value = false;
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
                              const ColoredBox(color: Colors.black),
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
                      return StreamBuilder<Duration>(
                        stream: slot.player.stream.position,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          if (hasFrame && position.inMilliseconds > 300) {
                            return const SizedBox.shrink();
                          }
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
                      );
                    },
                  )
                else
                  IgnorePointer(child: _buildPoster(currentFit, shouldCover)),

                // 3. Low internet / loading buffering Lottie animation
                if (slot != null)
                  ValueListenableBuilder<bool>(
                    valueListenable: slot.isBuffering,
                    builder: (context, isBuffering, _) {
                      if (!isBuffering) return const SizedBox.shrink();
                      return const VideoLoadingIndicator();
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
                        child: Padding(
                          padding: const EdgeInsets.all(12),
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
            errorBuilder: (context, error, stackTrace) => _blackContainer,
          ),
        ),
      );
    }
    return _blackContainer;
  }
}
