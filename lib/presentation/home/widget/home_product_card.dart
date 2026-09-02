import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/home_product_card_provider.dart';
import 'package:binetatour/core/widgets/shimmer/cool_shimmer_kit.dart';

class HomeProductCard extends StatelessWidget {
  final String videoUrl;
  final String assetThumbnail;
  final String title;
  final String price;
  final String? oldPrice;
  final String? discount;

  const HomeProductCard({
    super.key,
    required this.videoUrl,
    required this.assetThumbnail,
    required this.title,
    required this.price,
    this.oldPrice,
    this.discount,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeProductCardProvider(videoUrl: videoUrl),
      child: Consumer<HomeProductCardProvider>(
        builder: (context, provider, child) {
          final isVideoReady = provider.isVideoReady;
          final isPlaying = provider.isPlaying;
          final isInitializing = provider.isInitializing;
          final isBuffering = provider.isBuffering;
          final hasStartedPlaying = provider.hasStartedPlaying;
          final hasError = provider.hasError;

          return GestureDetector(
            onTap: isVideoReady ? provider.togglePlayPause : provider.playVideo,
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Video Layer (ALWAYS IN TREE so libmpv can attach to surface)
                  if (isVideoReady)
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width:
                              provider.player!.state.width?.toDouble() ?? 16.0,
                          height:
                              provider.player!.state.height?.toDouble() ?? 9.0,
                          child: Video(
                            controller: provider.videoController!,
                            controls: NoVideoControls,
                          ),
                        ),
                      ),
                    ),

                  // 2. Thumbnail (On top, hides when playing starts and buffering ends, shows when paused)
                  if (!isPlaying || !hasStartedPlaying)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black,
                        child: Image.asset(
                          assetThumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.grey.shade900,
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 3. Dark Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),

                  // 4. Discount Badge (Top Left)
                  if (discount != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          discount!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // 5. Play / Pause Icon (Center) — shown when not playing
                  if (!isInitializing && !hasError)
                    if (!isVideoReady || (isVideoReady && !isPlaying))
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),

                  // 6. Loading Indicator (Only shown during playback buffering)
                  if (isInitializing || (hasStartedPlaying && isBuffering))
                    const Center(
                      child: CoolShimmer(
                        child: CoolShimmerBone.circle(size: 38),
                      ),
                    ),

                  // 7. Error State
                  if (hasError)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.white70,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap to retry',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 8. Product Details (Bottom)
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
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              price,
                              style: const TextStyle(
                                color: Color(0xFFE8500A),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (oldPrice != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                oldPrice!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
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
        },
      ),
    );
  }
}
