import 'package:flutter/material.dart';

class HomeSkeletonLoader extends StatefulWidget {
  const HomeSkeletonLoader({super.key});

  @override
  State<HomeSkeletonLoader> createState() => _HomeSkeletonLoaderState();
}

class _HomeSkeletonLoaderState extends State<HomeSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _animation = Tween<double>(
      begin: -1.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    double borderRadius = 12,
    ShapeBorder? shape,
  }) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final gradient = LinearGradient(
          begin: Alignment(_animation.value - 1, 0),
          end: Alignment(_animation.value + 1, 0),
          colors: const [
            Color(0xFFEEEEEE),
            Color(0xFFF5F5F5),
            Color(0xFFE0E0E0),
            Color(0xFFF5F5F5),
            Color(0xFFEEEEEE),
          ],
          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
        );

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: shape == null
                ? BorderRadius.circular(borderRadius)
                : null,
            shape: shape is CircleBorder ? BoxShape.circle : BoxShape.rectangle,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Banner Video Skeleton
          Padding(
            padding: const EdgeInsets.all(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildShimmerBox(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 16,
              ),
            ),
          ),

          // 2. Section Header: "Clients Livrés 🙍‍♂️"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildShimmerBox(width: 160, height: 22, borderRadius: 6),
                _buildShimmerBox(
                  width: 32,
                  height: 32,
                  shape: const CircleBorder(),
                ),
              ],
            ),
          ),

          // 3. Horizontal Stories List Skeleton
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      _buildShimmerBox(
                        width: 68,
                        height: 68,
                        shape: const CircleBorder(),
                      ),
                      const SizedBox(height: 8),
                      _buildShimmerBox(width: 55, height: 10, borderRadius: 4),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // 4. Product Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildShimmerBox(width: 180, height: 22, borderRadius: 6),
                _buildShimmerBox(width: 60, height: 14, borderRadius: 4),
              ],
            ),
          ),

          // 5. Product Cards Row Skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildShimmerBox(
                    width: double.infinity,
                    height: 240,
                    borderRadius: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildShimmerBox(
                    width: double.infinity,
                    height: 240,
                    borderRadius: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
