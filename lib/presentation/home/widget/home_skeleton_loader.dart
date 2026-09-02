import 'package:binetatour/core/widgets/shimmer/cool_shimmer_kit.dart';
import 'package:flutter/material.dart';

/// Ultra-smooth, hardware-accelerated Skeleton Loader for Home Page
class HomeSkeletonLoader extends StatelessWidget {
  const HomeSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return CoolShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Banner Video Skeleton
            const Padding(
              padding: EdgeInsets.all(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CoolShimmerBone(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 16,
                ),
              ),
            ),

            // 2. Section Header: Stories
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CoolShimmerBone(width: 160, height: 22, borderRadius: 6),
                  CoolShimmerBone.circle(size: 32),
                ],
              ),
            ),

            // 3. Horizontal Stories Row
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 6,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  return const Column(
                    children: [
                      CoolShimmerBone.circle(size: 68),
                      SizedBox(height: 8),
                      CoolShimmerBone(width: 55, height: 10, borderRadius: 4),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // 4. Product Section Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CoolShimmerBone(width: 180, height: 22, borderRadius: 6),
                  CoolShimmerBone(width: 60, height: 14, borderRadius: 4),
                ],
              ),
            ),

            // 5. Product Cards Row
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: ShimmerCard.product(height: 250)),
                  SizedBox(width: 14),
                  Expanded(child: ShimmerCard.product(height: 250)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 6. Second Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CoolShimmerBone(width: 150, height: 20, borderRadius: 6),
                  CoolShimmerBone(width: 50, height: 14, borderRadius: 4),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: ShimmerCard.product(height: 250)),
                  SizedBox(width: 14),
                  Expanded(child: ShimmerCard.product(height: 250)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
