import 'package:binetatour/presentation/shop/shop_screen.dart';
import 'package:flutter/material.dart';

class ShopProductCard extends StatelessWidget {
  final List<ProductContent> content;
  final String? assetThumbnail;
  final String title;
  final String price;
  final String? oldPrice;
  final String? discount;

  // Logic Control Flags
  final bool showDiscountPercentage; // Controls the red badge
  final bool showOldPrice; // Controls the strikethrough text

  ShopProductCard({
    super.key,
    required this.content,
    this.assetThumbnail,
    required this.title,
    required this.price,
    this.oldPrice,
    this.discount,
    this.showDiscountPercentage = true, // Default to true
    this.showOldPrice = true, // Default to true
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180, // Adjusted width for better spacing
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          30,
        ), // Match the rounded look in image
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Thumbnail
          if (assetThumbnail == null || assetThumbnail!.isEmpty)
            Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 50,
                  color: Colors.black45,
                ),
              ),
            )
          else
            assetThumbnail!.startsWith('http')
                ? Image.network(
                    assetThumbnail!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  )
                : Image.asset(assetThumbnail!, fit: BoxFit.cover),

          // 2. Dark Gradient Overlay (Heavier at the bottom)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.9),
                ],
                stops: const [0.4, 0.7, 1.0],
              ),
            ),
          ),

          // 3. Discount Badge (Conditional)
          if (showDiscountPercentage && discount != null)
            Positioned(
              top: 15,
              left: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF1111), // Bright red from image
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  discount!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // 4. Product Details
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Wrap current price in Flexible so it doesn't push the old price off-screen
                    Text(
                      price,
                      style: const TextStyle(
                        color: Color(0xFFFF8000),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),

                    // Old Price (Conditional)
                    if (showOldPrice && oldPrice != null) ...[
                      // Reduced spacing slightly
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2.0),
                          child: Text(
                            oldPrice!,
                            style: const TextStyle(
                              color: Color(0xFFCC3333),
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                              decorationThickness: 2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
    );
  }
}
