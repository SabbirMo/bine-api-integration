import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:binetatour/core/video/feed_video_manager.dart';
import 'package:binetatour/core/video/video_frame_manager.dart';

class ShortsProductCard extends StatefulWidget {
  final String keyString;
  final String videoUrl;
  final String? thumbnailUrl;
  final String title;
  final String price;
  final String? oldPrice;
  final String? discount;
  final double width;
  final double height;
  final VoidCallback onTap;

  const ShortsProductCard({
    super.key,
    required this.keyString,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.title,
    required this.price,
    this.oldPrice,
    this.discount,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  State<ShortsProductCard> createState() => _ShortsProductCardState();
}

class _ShortsProductCardState extends State<ShortsProductCard> {
  void _reportVisibility(double visibleFraction) {
    if (!mounted) return;
    double cardCenterY = 0.0;
    try {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final globalOffset = renderBox.localToGlobal(Offset.zero);
        cardCenterY = globalOffset.dy + (renderBox.size.height / 2);
        final screenHeight = MediaQuery.sizeOf(context).height;
        FeedVideoManager.instance.updateViewportHeight(screenHeight);
      }
    } catch (_) {}

    FeedVideoManager.instance.onCardVisibilityChanged(
      widget.keyString,
      widget.videoUrl,
      visibleFraction,
      cardCenterY: cardCenterY,
    );
  }

  @override
  void initState() {
    super.initState();
    FeedVideoManager.instance.registerCardContext(widget.keyString, context);
    if (widget.videoUrl.trim().isNotEmpty) {
      FeedVideoManager.instance.registerCardUrl(
        widget.keyString,
        widget.videoUrl,
      );
      VideoFrameManager.instance.extractFirstFrame(widget.videoUrl);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _reportVisibility(1.0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ShortsProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    FeedVideoManager.instance.registerCardContext(widget.keyString, context);
    if (oldWidget.keyString != widget.keyString ||
        oldWidget.videoUrl != widget.videoUrl) {
      if (oldWidget.keyString != widget.keyString) {
        FeedVideoManager.instance.unregisterCardContext(oldWidget.keyString);
        FeedVideoManager.instance.unregisterCard(oldWidget.keyString);
      }
      if (widget.videoUrl.trim().isNotEmpty) {
        FeedVideoManager.instance.registerCardUrl(
          widget.keyString,
          widget.videoUrl,
        );
        VideoFrameManager.instance.extractFirstFrame(widget.videoUrl);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _reportVisibility(1.0);
          }
        });
      } else {
        FeedVideoManager.instance.unregisterCard(widget.keyString);
      }
    }
  }

  @override
  void dispose() {
    FeedVideoManager.instance.unregisterCardContext(widget.keyString);
    FeedVideoManager.instance.unregisterCard(widget.keyString);
    super.dispose();
  }

  Widget _buildBannerStyleLoading() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Color(0xFFFFF1E6),
          shape: BoxShape.circle,
        ),
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: Color(0xFFFF6900),
            strokeWidth: 3,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoFirstFrame() {
    return ListenableBuilder(
      listenable: VideoFrameManager.instance,
      builder: (context, _) {
        final frameBytes =
            VideoFrameManager.instance.getCachedFrame(widget.videoUrl);

        if (frameBytes != null && frameBytes.isNotEmpty) {
          return Image.memory(
            frameBytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }

        // Trigger extraction in background if not already cached
        VideoFrameManager.instance.extractFirstFrame(widget.videoUrl);

        // Immediately show the product thumbnail if available
        if (widget.thumbnailUrl != null &&
            widget.thumbnailUrl!.trim().isNotEmpty) {
          return _buildFallbackImage();
        }

        return Container(
          color: const Color(0xFF161616),
          child: _buildBannerStyleLoading(),
        );
      },
    );
  }

  Widget _buildFallbackImage() {
    final thumb = widget.thumbnailUrl ?? '';
    if (thumb.isEmpty) {
      return Container(color: const Color(0xFF161616));
    }

    if (thumb.startsWith('http')) {
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(color: const Color(0xFF161616)),
      );
    }

    return Image.asset(
      thumb,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(color: const Color(0xFF161616)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.videoUrl.trim().isNotEmpty;

    return VisibilityDetector(
      key: Key(widget.keyString),
      onVisibilityChanged: (info) {
        if (hasVideo) {
          _reportVisibility(info.visibleFraction);
        }
      },
      child: GestureDetector(
        onTap: () {
          if (hasVideo) {
            FeedVideoManager.instance.playSingle(
              widget.keyString,
              widget.videoUrl,
            );
          }
          widget.onTap();
        },
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF161616),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Base Layer: The ACTUAL FIRST FRAME extracted directly from the video file (NO external catalog thumbnail!)
              if (hasVideo) _buildVideoFirstFrame() else _buildFallbackImage(),

              // 2. Active Video Player Layer (Plays smoothly right on top of the first frame)
              if (hasVideo)
                ListenableBuilder(
                  listenable: FeedVideoManager.instance,
                  builder: (context, _) {
                    final playerState =
                        FeedVideoManager.instance.getPlayerState(
                      widget.keyString,
                    );
                    final isAttached =
                        playerState != null &&
                        playerState.currentUrl == widget.videoUrl;

                    if (isAttached) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          SizedBox.expand(
                            child: Video(
                              controller: playerState.videoController,
                              fit: BoxFit.cover,
                              controls: NoVideoControls,
                            ),
                          ),
                          if (playerState.isPlaying && playerState.isBuffering)
                            _buildBannerStyleLoading(),
                        ],
                      );
                    }

                    return const SizedBox();
                  },
                ),

              // 3. Bottom Gradient for high text readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.88),
                      ],
                      stops: const [0.4, 0.65, 1.0],
                    ),
                  ),
                ),
              ),

              // 4. Discount Badge (Top Left)
              if (widget.discount != null && widget.discount!.isNotEmpty)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF1111),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.discount!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // 5. Product Title & Price Details (Bottom)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black87,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          widget.price,
                          style: const TextStyle(
                            color: Color(0xFFFF8000),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        if (widget.oldPrice != null &&
                            widget.oldPrice!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            widget.oldPrice!.replaceAll(
                              RegExp(r'\s*FCFA', caseSensitive: false),
                              '',
                            ),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                              decorationThickness: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
