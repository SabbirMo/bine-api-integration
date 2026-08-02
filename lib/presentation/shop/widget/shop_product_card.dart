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

  // Custom sizing and styling options
  final double? width;
  final double? height;
  final bool isCompact;

  const ShopProductCard({
    super.key,
    required this.content,
    this.assetThumbnail,
    required this.title,
    required this.price,
    this.oldPrice,
    this.discount,
    this.showDiscountPercentage = true, // Default to true
    this.showOldPrice = true, // Default to true
    this.width,
    this.height,
    this.isCompact = false, // Default to false
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? (isCompact ? 110 : 180),
      height: height ?? (isCompact ? 150 : 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          isCompact ? 16 : 16,
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
              child: Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: isCompact ? 24 : 50,
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
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: isCompact ? 24 : 50,
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
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.9),
                ],
                stops: const [0.4, 0.7, 1.0],
              ),
            ),
          ),

          // 3. Discount Badge (Conditional)
          if (showDiscountPercentage && discount != null)
            Positioned(
              top: isCompact ? 8 : 15,
              left: isCompact ? 8 : 15,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 8 : 14,
                  vertical: isCompact ? 4 : 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF1111), // Bright red from image
                  borderRadius: BorderRadius.circular(isCompact ? 12 : 25),
                ),
                child: Text(
                  discount!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 10 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // 4. Product Details
          Padding(
            padding: EdgeInsets.all(isCompact ? 8.0 : 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isCompact ? 12 : 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isCompact ? 2 : 4),
                isCompact
                    ? Wrap(
                        children: [
                          Text(
                            price,
                            style: const TextStyle(
                              color: Color(0xFFFF8000),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                          const SizedBox(width: 6),
                          if (showOldPrice && oldPrice != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              oldPrice!.replaceAll(
                                RegExp(r'\s*FCFA', caseSensitive: false),
                                '',
                              ),
                              style: const TextStyle(
                                color: Color(0xFFCC3333),
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                                decorationThickness: 1.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                          ],
                        ],
                      )
                    : Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            price,
                            style: const TextStyle(
                              color: Color(0xFFFF8000),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),

                          // Old Price (Conditional)
                          if (showOldPrice && oldPrice != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Text(
                                oldPrice!.replaceAll(
                                  RegExp(r'\s*FCFA', caseSensitive: false),
                                  '',
                                ),
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
