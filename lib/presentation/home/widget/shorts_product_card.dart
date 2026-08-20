import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:binetatour/core/video/feed_video_manager.dart';

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
  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.trim().isNotEmpty) {
      FeedVideoManager.instance.registerCardUrl(
        widget.keyString,
        widget.videoUrl,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ShortsProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      if (widget.videoUrl.trim().isNotEmpty) {
        FeedVideoManager.instance.registerCardUrl(
          widget.keyString,
          widget.videoUrl,
        );
      } else {
        FeedVideoManager.instance.unregisterCard(widget.keyString);
      }
    }
  }

  @override
  void dispose() {
    FeedVideoManager.instance.unregisterCard(widget.keyString);
    super.dispose();
  }

  Widget _buildBannerStyleLoading() {
    return Container(
      color: const Color(0xFF161616),
      child: Center(
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
      ),
    );
  }

  Widget _buildThumbnail() {
    final thumb = widget.thumbnailUrl ?? '';

    if (thumb.isEmpty) {
      return Container(
        color: const Color(0xFF1E1E1E),
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.white24,
            size: 32,
          ),
        ),
      );
    }

    if (thumb.startsWith('http')) {
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildBannerStyleLoading();
        },
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFF1E1E1E),
          child: const Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Colors.white24,
              size: 32,
            ),
          ),
        ),
      );
    }

    return Image.asset(
      thumb,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFF1E1E1E),
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.white24,
            size: 32,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.videoUrl.trim().isNotEmpty;

    return GestureDetector(
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
          color: const Color(0xFF141414),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Video Player Layer (When attached) OR Thumbnail/Poster
            if (hasVideo)
              ListenableBuilder(
                listenable: FeedVideoManager.instance,
                builder: (context, _) {
                  final playerState = FeedVideoManager.instance.getPlayerState(
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
                        if (playerState.isBuffering &&
                            !playerState.hasFirstFrame)
                          _buildBannerStyleLoading(),
                      ],
                    );
                  }

                  return _buildThumbnail();
                },
              )
            else
              _buildThumbnail(),

            // 2. Bottom Gradient for high text readability
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

            // 3. Discount Badge (Top Left)
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

            // 4. Product Title & Price Details (Bottom)
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
    );
  }
}
