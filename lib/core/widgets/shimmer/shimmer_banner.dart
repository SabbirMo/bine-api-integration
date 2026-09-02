import 'package:flutter/material.dart';
import 'cool_shimmer.dart';

/// Shimmer Skeleton for Video Players, Promotional Banners, and Hero Carousels.
class ShimmerBanner extends StatelessWidget {
  final double? width;
  final double? height;
  final double aspectRatio;
  final double borderRadius;
  final bool showPlayIcon;
  final bool showBottomControls;
  final EdgeInsetsGeometry margin;

  const ShimmerBanner({
    super.key,
    this.width = double.infinity,
    this.height,
    this.aspectRatio = 16 / 9,
    this.borderRadius = 16,
    this.showPlayIcon = true,
    this.showBottomControls = true,
    this.margin = EdgeInsets.zero,
  });

  /// Const constructor specifically tailored for Feed Video Player
  const ShimmerBanner.video({
    super.key,
    this.width = double.infinity,
    this.height = 240,
    this.aspectRatio = 16 / 9,
    this.borderRadius = 18,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  })  : showPlayIcon = true,
        showBottomControls = true;

  /// Const constructor for Promo/Ad Banner
  const ShimmerBanner.promo({
    super.key,
    this.width = double.infinity,
    this.height = 150,
    this.aspectRatio = 16 / 9,
    this.borderRadius = 14,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  })  : showPlayIcon = false,
        showBottomControls = false;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base Background Bone
          const CoolShimmerBone(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
          ),

          // Center Play Button / Buffering Circle
          if (showPlayIcon)
            const Center(
              child: CoolShimmerBone.circle(size: 52),
            ),

          // Top Info Tag / Live Badge
          const Positioned(
            top: 14,
            left: 14,
            child: CoolShimmerBone.pill(
              width: 58,
              height: 24,
            ),
          ),

          // Bottom Controls & Scrub Bar Skeleton
          if (showBottomControls)
            const Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CoolShimmerBone(
                    width: 140,
                    height: 12,
                    borderRadius: 3,
                  ),
                  SizedBox(height: 8),
                  // Video Progress Bar Track
                  CoolShimmerBone(
                    width: double.infinity,
                    height: 4,
                    borderRadius: 2,
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (height == null) {
      content = AspectRatio(
        aspectRatio: aspectRatio,
        child: content,
      );
    }

    return CoolShimmer(child: content);
  }
}
