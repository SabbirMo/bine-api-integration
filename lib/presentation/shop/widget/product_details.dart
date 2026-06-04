import 'package:binetatour/presentation/shop/vaildation_sceen.dart';
import 'package:binetatour/presentation/shop/widget/cart_screen.dart';
import 'package:binetatour/presentation/shop/widget/product_video_item.dart';
import 'package:binetatour/presentation/shop/widget/shop_product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class ProductDetailsScreen extends StatefulWidget {
  final List<ShopProductCard>
  allProducts; // The list of all products for vertical scroll
  final int initialProductIndex; // The product the user clicked on

  const ProductDetailsScreen({
    super.key,
    required this.allProducts,
    this.initialProductIndex = 0,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late PageController _verticalController;
  bool _isMuted = false;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _verticalController = PageController(
      initialPage: widget.initialProductIndex,
    );
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          controller: _verticalController,
          scrollDirection: Axis.vertical, // SWIPE UP FOR NEXT PRODUCT
          itemCount: widget.allProducts.length,
          itemBuilder: (context, index) {
            final product = widget.allProducts[index];
            return ProductMediaGallery(
              product: product,
              isMuted: _isMuted,
              onMuteToggle: () => setState(() => _isMuted = !_isMuted),
              isExpanded: _isExpanded,
            );
          },
        ),
      ),
    );
  }
}

/// This widget handles the Horizontal Media for a SINGLE product
class ProductMediaGallery extends StatefulWidget {
  final ShopProductCard product;
  final bool isMuted;
  bool isExpanded;
  final VoidCallback onMuteToggle;

  ProductMediaGallery({
    super.key,
    required this.product,
    required this.isExpanded,
    required this.isMuted,
    required this.onMuteToggle,
  });

  @override
  State<ProductMediaGallery> createState() => _ProductMediaGalleryState();
}

class _ProductMediaGalleryState extends State<ProductMediaGallery> {
  int _currentMediaIndex = 0;
  late PageController _horizontalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = PageController();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. HORIZONTAL MEDIA (Images and Videos mix)
        PageView.builder(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          itemCount: widget.product.content.length,
          onPageChanged: (i) => setState(() => _currentMediaIndex = i),
          itemBuilder: (context, index) {
            final media = widget.product.content[index];
            if (media.isVideo) {
              return ProductVideoItem(
                videoUrl: media.url,
                isMuted: widget.isMuted,
              );
            } else {
              return InteractiveViewer(
                child: Image.network(
                  media.url,
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              );
            }
          },
        ),

        // 2. TOP UI OVERLAY
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Media Counter (e.g., 1/3)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${_currentMediaIndex + 1} / ${widget.product.content.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                // Mute button only for Videos
                if (widget.product.content[_currentMediaIndex].isVideo)
                  _buildCircleIcon(
                    icon: widget.isMuted ? Icons.volume_off : Icons.volume_up,
                    onTap: widget.onMuteToggle,
                  ),
                const SizedBox(width: 10),
                _buildCircleIcon(
                  icon: Icons.close,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),

        // 3. RIGHT SIDE ACTIONS
        Positioned(
          right: 0,
          bottom: widget.isExpanded ? 170 : 135,
          child: Column(
            children: [
              InkWell(
                onTap: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        "Produit ajouté au panier avec succès !",
                        textAlign: TextAlign.center, // Optional: center text
                      ),
                      backgroundColor: const Color(0xFFFF6900),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      // This is the magic part for top positioning:
                      margin: EdgeInsets.only(
                        bottom:
                            MediaQuery.of(context).size.height -
                            120, // Pushes it to the top
                        left: 20,
                        right: 20,
                      ),
                    ),
                  );
                  await Future.delayed(const Duration(seconds: 2));
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true, // Allows it to take more height
                    backgroundColor: Colors.transparent,
                    builder: (context) => const CartBottomSheet(),
                  );
                },
                child: _buildActionIcon(Icons.add, "Panier"),
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white),
                    ),
                    child: SvgPicture.asset(
                      "assets/icon/ic_baseline-whatsapp.svg",
                      height: 25,
                      width: 25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Whatsapp",
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
              SizedBox(height: 20),

              SvgPicture.asset(
                "assets/icon/mdi_share.svg",
                color: Colors.white,
                height: 25,
                width: 25,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // 4. BOTTOM GRADIENT INFO
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 40, 20, 0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 25.0),
                  child: Container(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ValidationScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6900),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      label: const Text(
                        "J'ACHÈTE",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      icon: SvgPicture.asset(
                        "assets/icon/cart_black.svg",
                        height: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      widget.product.price,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.product.showOldPrice &&
                        widget.product.oldPrice != null) ...[
                      // Reduced spacing slightly
                      SizedBox(width: 5),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 4.0,
                          ), // Slightly more padding for clarity
                          child: Text(
                            widget.product.oldPrice!,
                            style: TextStyle(
                              // Use a light grey/white that matches the image exactly
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.lineThrough,
                              // Ensure the line is the same color as the text
                              decorationColor: Colors.white.withOpacity(0.7),
                              decorationThickness: 1.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        "Description: ${widget.product.title} - Ballon de compétition haute performance. Idéal pour les matchs officiels sur gazon naturel ou synthétique. Résistant à l'usure et imperméable.",
                        // Toggle between 1 and 100 lines
                        maxLines: widget.isExpanded ? 100 : 1,
                        overflow: widget.isExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize:
                              14, // Reduced slightly for better readability
                          height: 1.4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          widget.isExpanded = !widget.isExpanded;
                        });
                      },
                      child:  widget.isExpanded ?  Icon(
                        
                            Icons.arrow_upward,
                           
                        color: Colors.white,
                        size: 24,
                      ) : SvgPicture.asset("assets/icon/mdi_arrow-down-thin.svg") 
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
