import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/product_provider.dart';
import 'package:binetatour/core/utils/media_url_resolver.dart';
import 'package:binetatour/core/video/reels_video_controller_pool.dart';

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

  @override
  void initState() {
    super.initState();
    _computeCachedUrls();
    final itemIdx = widget.itemIndex ?? widget.productId;
    _slot = ReelsVideoControllerPool.instance.getSlotForIndex(
      itemIdx,
      _cachedVideoUrl,
    );
    if (widget.isActive) {
      if (_slot == null ||
          ReelsVideoControllerPool.instance.activeProductIndex != itemIdx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.isActive) {
            _activateSlot();
            setState(() {});
          }
        });
      } else {
        if (!_slot!.player.state.playing) {
          try {
            _slot!.player.play();
          } catch (_) {}
        }
      }
    }
  }

  void _computeCachedUrls() {
    _cachedVideoUrl = _resolveVideoUrl();
    _cachedThumbnail = _computeThumbnail();
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
      if (!existing.player.state.playing) {
        try {
          existing.player.play();
        } catch (_) {}
      }
    } else {
      _slot = ReelsVideoControllerPool.instance.activateVideo(
        itemIndex: itemIdx,
        url: _cachedVideoUrl,
        nextUrls: widget.upcomingUrls,
      );
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
      if (widget.isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.isActive) {
            _activateSlot();
            setState(() {});
          }
        });
      } else {
        _slot = null;
        setState(() {});
      }
    } else if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        final itemIdx = widget.itemIndex ?? widget.productId;
        _slot = ReelsVideoControllerPool.instance.getSlotForIndex(
          itemIdx,
          _cachedVideoUrl,
        );
        if (_slot == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.isActive) {
              _activateSlot();
              setState(() {});
            }
          });
        }
        setState(() {});
      } else {
        try {
          _slot?.player.pause();
        } catch (_) {}
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = _slot;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (slot != null) {
          if (slot.player.state.playing) {
            slot.player.pause();
          } else {
            slot.player.play();
          }
          // No setState needed — ValueListenableBuilder on slot.isPlaying handles UI
        }
      },
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Live Video Surface — width fits the screen perfectly
            if (slot != null)
              RepaintBoundary(
                child: SizedBox.expand(
                  child: Center(
                    child: Video(
                      controller: slot.videoController,
                      controls: NoVideoControls,
                      fit: BoxFit.fitWidth,
                      fill: Colors.transparent,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),

            // 2. Poster Image — continuous AnimatedOpacity crossfade to video when first frame renders
            if (slot != null)
              ValueListenableBuilder<bool>(
                valueListenable: slot.hasFirstFrame,
                child: _buildPoster(),
                builder: (context, hasFrame, child) {
                  return IgnorePointer(
                    ignoring: hasFrame,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      opacity: hasFrame ? 0.0 : 1.0,
                      child: child,
                    ),
                  );
                },
              )
            else
              IgnorePointer(child: _buildPoster()),

            // 3. Low internet / loading buffering spinner
            if (slot != null)
              ValueListenableBuilder<bool>(
                valueListenable: slot.isBuffering,
                builder: (context, isBuffering, _) {
                  if (!isBuffering) return const SizedBox.shrink();
                  return const Center(
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFE8500A),
                        ),
                      ),
                    ),
                  );
                },
              ),

            // 3. Play icon overlay — uses ValueListenableBuilder instead of setState
            if (slot != null)
              ValueListenableBuilder<bool>(
                valueListenable: slot.isPlaying,
                builder: (context, isPlaying, child) {
                  if (isPlaying) return const SizedBox.shrink();
                  return child!;
                },
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: DecoratedBox(
                      decoration: _playIconDecoration,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoster() {
    if (_cachedThumbnail.isNotEmpty) {
      return SizedBox.expand(
        child: Center(
          child: Image.network(
            _cachedThumbnail,
            fit: BoxFit.fitWidth,
            width: double.infinity,
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
