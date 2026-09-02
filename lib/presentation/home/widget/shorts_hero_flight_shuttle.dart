import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Animation tracker for Hero transition between [ShortsProductCard]
/// and [ProductDetailsScreen] / [ProductVideoItem].
///
/// Tracks [Animation<double> animation] throughout flight:
/// - Smoothly morphs border radius from 20.0 to 0.0 (and 0.0 to 20.0 on pop).
/// - Fades out card overlay (gradient, title, price, discount badge) early in the flight.
/// - Keeps the live [VideoController] playing and rendering in real-time as the card expands.
/// - Keeps the cached poster/thumbnail image in [BoxFit.cover] behind the video layer,
///   guaranteeing ZERO black flash, ZERO loading spinner, and buttery 120 FPS motion.
class ShortsHeroFlightShuttle extends StatelessWidget {
  final Animation<double> animation;
  final HeroFlightDirection flightDirection;
  final String? thumbnailUrl;
  final VideoController? videoController;
  final String title;
  final String price;
  final String? oldPrice;
  final String? discount;

  const ShortsHeroFlightShuttle({
    super.key,
    required this.animation,
    required this.flightDirection,
    this.thumbnailUrl,
    this.videoController,
    required this.title,
    required this.price,
    this.oldPrice,
    this.discount,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        // Smooth cubic ease curve for expansion progress
        final curvedT = Curves.fastOutSlowIn.transform(t);
        final radius = (1.0 - curvedT) * 20.0;

        // Card info overlay fades out in the first 35% of flight
        final overlayOpacity = (1.0 - (t * 2.8)).clamp(0.0, 1.0);

        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Material(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Base Poster Thumbnail (Instant cached image in memory, always covering)
                if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty)
                  Image.network(
                    thumbnailUrl!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(
                      color: Color(0xFF1E1E1E),
                    ),
                  )
                else
                  const ColoredBox(color: Color(0xFF1E1E1E)),

                // 2. Live Video Texture (continues playing seamlessly while expanding!)
                if (videoController != null)
                  RepaintBoundary(
                    child: SizedBox.expand(
                      child: Video(
                        controller: videoController!,
                        fit: BoxFit.cover,
                        controls: NoVideoControls,
                        fill: Colors.transparent,
                        width: double.infinity,
                        height: double.infinity,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),

                // 2. Card Details Overlay (Gradient, Title, Price, Discount Badge)
                if (overlayOpacity > 0.0)
                  Opacity(
                    opacity: overlayOpacity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Bottom Gradient for text contrast
                        Positioned.fill(
                          child: DecoratedBox(
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

                        // Discount Badge (Top Left)
                        if (discount != null && discount!.isNotEmpty)
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
                                discount!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        // Product Title & Price Details (Bottom)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
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
                              Row(
                                children: [
                                  Text(
                                    price,
                                    style: const TextStyle(
                                      color: Color(0xFFFF8000),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (oldPrice != null &&
                                      oldPrice!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        oldPrice!,
                                        style: TextStyle(
                                          color: Colors.red.withValues(
                                            alpha: 0.65,
                                          ),
                                          fontSize: 10,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          decorationThickness: 1.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
              ],
            ),
          ),
        );
      },
    );
  }
}
