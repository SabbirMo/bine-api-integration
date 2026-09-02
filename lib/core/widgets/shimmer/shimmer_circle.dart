import 'package:flutter/material.dart';
import 'cool_shimmer.dart';

/// Shimmer Skeleton for Avatars, Story Circles, Profile Images, and Icon Buttons.
class ShimmerCircle extends StatelessWidget {
  final double size;
  final bool hasBorder;
  final double borderWidth;
  final bool showLabel;
  final double labelWidth;

  const ShimmerCircle({
    super.key,
    this.size = 56,
    this.hasBorder = false,
    this.borderWidth = 2.0,
    this.showLabel = false,
    this.labelWidth = 50,
  });

  /// Const named constructor for Story Circles (matching CircularStoryAvatar)
  const ShimmerCircle.story({
    super.key,
    this.size = 72,
    this.showLabel = true,
    this.labelWidth = 56,
  })  : hasBorder = true,
        borderWidth = 2.5;

  /// Const named constructor for Profile Header Avatar
  const ShimmerCircle.profile({
    super.key,
    this.size = 88,
  })  : hasBorder = true,
        borderWidth = 3.0,
        showLabel = false,
        labelWidth = 0;

  /// Const named constructor for Icon Buttons / Actions
  const ShimmerCircle.iconButton({
    super.key,
    this.size = 40,
  })  : hasBorder = false,
        borderWidth = 0,
        showLabel = false,
        labelWidth = 0;

  @override
  Widget build(BuildContext context) {
    return CoolShimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(hasBorder ? borderWidth * 1.5 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: hasBorder
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: borderWidth,
                    )
                  : null,
            ),
            child: CoolShimmerBone.circle(
              size: hasBorder ? size - (borderWidth * 3) : size,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 6),
            CoolShimmerBone(
              width: labelWidth,
              height: 10,
              borderRadius: 3,
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal scrolling row of Story Shimmers
class ShimmerStoryRow extends StatelessWidget {
  final int count;
  final double itemSize;
  final EdgeInsetsGeometry padding;

  const ShimmerStoryRow({
    super.key,
    this.count = 6,
    this.itemSize = 72,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemSize + 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: count,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) => ShimmerCircle.story(size: itemSize),
      ),
    );
  }
}
