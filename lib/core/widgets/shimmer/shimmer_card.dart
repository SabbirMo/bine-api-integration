import 'package:flutter/material.dart';
import 'cool_shimmer.dart';

/// Shimmer Skeleton for Product Cards, Grid Items, and Feed Cards.
class ShimmerCard extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool showBadge;
  final bool isHorizontal;

  const ShimmerCard({
    super.key,
    this.width = 160,
    this.height = 240,
    this.borderRadius = 20,
    this.showBadge = true,
    this.isHorizontal = false,
  });

  /// Const named constructor for a standard Home/Shop Product Card
  const ShimmerCard.product({
    super.key,
    this.width = 160,
    this.height = 240,
    this.borderRadius = 20,
    this.showBadge = true,
  }) : isHorizontal = false;

  /// Const named constructor for horizontal card layout
  const ShimmerCard.horizontal({
    super.key,
    this.width = double.infinity,
    this.height = 110,
    this.borderRadius = 15,
    this.showBadge = false,
  }) : isHorizontal = true;

  @override
  Widget build(BuildContext context) {
    return CoolShimmer(
      child: isHorizontal ? _buildHorizontalCard() : _buildVerticalCard(),
    );
  }

  Widget _buildVerticalCard() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image Block
          const CoolShimmerBone(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
          ),

          // 2. Optional Badge (Top Left)
          if (showBadge)
            const Positioned(
              top: 10,
              left: 10,
              child: CoolShimmerBone.pill(
                width: 48,
                height: 22,
              ),
            ),

          // 3. Play Icon Indicator (Center)
          const Center(
            child: CoolShimmerBone.circle(size: 38),
          ),

          // 4. Bottom Info Section (Title + Price)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title line 1
                const CoolShimmerBone(
                  width: double.infinity,
                  height: 14,
                  borderRadius: 4,
                ),
                const SizedBox(height: 6),
                // Title line 2 (shorter)
                const CoolShimmerBone(
                  width: 80,
                  height: 12,
                  borderRadius: 4,
                ),
                const SizedBox(height: 8),
                // Price & Old Price
                const Row(
                  children: [
                    CoolShimmerBone(
                      width: 60,
                      height: 14,
                      borderRadius: 4,
                    ),
                    SizedBox(width: 8),
                    CoolShimmerBone(
                      width: 35,
                      height: 10,
                      borderRadius: 3,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCard() {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Row(
        children: [
          // Left Image Thumbnail
          CoolShimmerBone(
            width: 86,
            height: 86,
            borderRadius: 12,
          ),
          SizedBox(width: 14),
          // Right Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CoolShimmerBone(
                  width: double.infinity,
                  height: 14,
                  borderRadius: 4,
                ),
                SizedBox(height: 8),
                CoolShimmerBone(
                  width: 120,
                  height: 12,
                  borderRadius: 4,
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CoolShimmerBone(
                      width: 70,
                      height: 14,
                      borderRadius: 4,
                    ),
                    CoolShimmerBone.pill(
                      width: 60,
                      height: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
