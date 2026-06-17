// ignore_for_file: must_be_immutable

import 'package:binetatour/core/token_storage/token_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:binetatour/presentation/profile/widget/login_view.dart';
import 'package:binetatour/presentation/shop/vaildation_sceen.dart';
import 'package:binetatour/presentation/shop/widget/cart_screen.dart';
import 'package:binetatour/presentation/shop/widget/product_video_item.dart';
import 'package:binetatour/presentation/shop/widget/product_audio_item.dart';
import 'package:binetatour/data/models/product_model.dart';
import 'package:binetatour/presentation/shop/shop_screen.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/product_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductDetailsScreen extends StatefulWidget {
  final List<ProductModel>
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

  bool isExpanded = false;

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
              isExpanded: isExpanded,
            );
          },
        ),
      ),
    );
  }
}

/// This widget handles the Horizontal Media for a SINGLE product
class ProductMediaGallery extends StatefulWidget {
  final ProductModel product;
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
  late ProductModel _product;
  bool _isLoadingDetails = true;

  List<ProductContent> get _mediaContent {
    if (_product.media.isNotEmpty) {
      return _product.media
          .map(
            (m) => ProductContent(
              url: m.mediaUrl,
              isVideo: m.mediaType == 'video',
              isImage: m.mediaType == 'image',
              isAudio: m.mediaType == 'audio',
              isNetwork: true,
            ),
          )
          .toList();
    } else if (_product.mainImage != null && _product.mainImage!.isNotEmpty) {
      return [
        ProductContent(
          url: _product.mainImage!,
          isVideo: false,
          isImage: true,
          isAudio: false,
          isNetwork: true,
        ),
      ];
    } else {
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    _horizontalController = PageController();
    _product = widget.product;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final detailedProduct = await context
        .read<ProductProvider>()
        .fetchProductDetails(widget.product.id);
    if (mounted && detailedProduct != null) {
      setState(() {
        _product = detailedProduct;
        _isLoadingDetails = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoadingDetails = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. HORIZONTAL MEDIA (Images and Videos mix)
        _mediaContent.isEmpty
            ? const Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 100,
                  color: Colors.white54,
                ),
              )
            : PageView.builder(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                itemCount: _mediaContent.length,
                onPageChanged: (i) => setState(() => _currentMediaIndex = i),
                itemBuilder: (context, index) {
                  final media = _mediaContent[index];
                  if (media.isVideo) {
                    return ProductVideoItem(
                      productId: _product.id,
                      videoUrl: media.url,
                      thumbnailUrl: _product.mainImage,
                      isMuted: widget.isMuted,
                    );
                  } else if (media.isAudio) {
                    return ProductAudioItem(
                      audioUrl: media.url,
                      isMuted: widget.isMuted,
                    );
                  } else {
                    return InteractiveViewer(
                      child: Image.network(
                        media.url,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 100,
                                color: Colors.white54,
                              ),
                            ),
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
                if (_mediaContent.isNotEmpty)
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
                      "${_currentMediaIndex + 1} / ${_mediaContent.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                // Mute button only for Videos and Audios
                if (_mediaContent.isNotEmpty &&
                    (_mediaContent[_currentMediaIndex].isVideo ||
                        _mediaContent[_currentMediaIndex].isAudio))
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
                  final user = FirebaseAuth.instance.currentUser;
                  final token = await TokenStorage.getAccessToken();

                  if (user == null && token == null) {
                    if (!mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => Scaffold(
                          backgroundColor: Colors.white,
                          appBar: AppBar(
                            backgroundColor: Colors.white,
                            elevation: 0,
                            iconTheme: const IconThemeData(color: Colors.black),
                          ),
                          body: LoginView(
                            onLogin: () {
                              Navigator.pop(ctx);
                            },
                          ),
                        ),
                      ),
                    );

                    // Check again after login attempt
                    final userAfter = FirebaseAuth.instance.currentUser;
                    final tokenAfter = await TokenStorage.getAccessToken();

                    if (userAfter == null && tokenAfter == null) {
                      return; // Still not logged in
                    }
                  }

                  if (!mounted) return;

                  context.read<CartProvider>().addToCart(_product);

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
                      margin: const EdgeInsets.all(20),
                    ),
                  );
                  await Future.delayed(const Duration(seconds: 2));
                  if (!mounted) return;
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
              InkWell(
                onTap: () async {
                  String shareText = '';

                  if (_mediaContent.isNotEmpty) {
                    shareText = _mediaContent[_currentMediaIndex].url;
                  } else if (_product.mainImage != null) {
                    shareText = _product.mainImage!;
                  }

                  if (shareText.isNotEmpty) {
                    final whatsappAppUrl = Uri.parse(
                      "whatsapp://send?text=${Uri.encodeComponent(shareText)}",
                    );
                    final whatsappWebUrl = Uri.parse(
                      "https://wa.me/?text=${Uri.encodeComponent(shareText)}",
                    );

                    bool launched = false;

                    if (await canLaunchUrl(whatsappAppUrl)) {
                      launched = await launchUrl(
                        whatsappAppUrl,
                        mode: LaunchMode.externalApplication,
                      );
                    }

                    if (!launched) {
                      launched = await launchUrl(
                        whatsappWebUrl,
                        mode: LaunchMode.externalApplication,
                      );
                    }

                    if (!launched) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "WhatsApp n'est pas installé sur cet appareil.",
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.6),
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
              ),
              SizedBox(height: 20),

              InkWell(
                onTap: () {
                  String shareText = '';

                  if (_mediaContent.isNotEmpty) {
                    shareText = _mediaContent[_currentMediaIndex].url;
                  } else if (_product.mainImage != null) {
                    shareText = _product.mainImage!;
                  }

                  if (shareText.isNotEmpty) {
                    // ignore: deprecated_member_use
                    Share.share(shareText);
                  }
                },
                child: Column(
                  children: [
                    SvgPicture.asset(
                      "assets/icon/mdi_share.svg",
                      // ignore: deprecated_member_use
                      color: Colors.white,
                      height: 25,
                      width: 25,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Partager",
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
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
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.9),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 25.0),
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final token = await TokenStorage.getAccessToken();
                        if (token == null || token.isEmpty) {
                          if (!context.mounted) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => Scaffold(
                                backgroundColor: Colors.white,
                                appBar: AppBar(
                                  backgroundColor: Colors.white,
                                  elevation: 0,
                                  iconTheme: const IconThemeData(
                                    color: Colors.black,
                                  ),
                                ),
                                body: LoginView(
                                  onLogin: () {
                                    Navigator.pop(ctx);
                                  },
                                ),
                              ),
                            ),
                          );

                          // Check again after login attempt
                          final tokenAfter =
                              await TokenStorage.getAccessToken();
                          if (tokenAfter == null || tokenAfter.isEmpty) {
                            return; // Still not logged in
                          }
                        }

                        if (!context.mounted) return;
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
                      "${_product.priceAfterDiscount} FCFA",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if ((double.tryParse(_product.discountPercentage) ?? 0) >
                        0) ...[
                      // Reduced spacing slightly
                      SizedBox(width: 5),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 4.0,
                          ), // Slightly more padding for clarity
                          child: Text(
                            "${_product.sellingPrice} FCFA",
                            style: TextStyle(
                              // Use a light grey/white that matches the image exactly
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.lineThrough,
                              // Ensure the line is the same color as the text
                              decorationColor: Colors.white.withValues(
                                alpha: 0.7,
                              ),
                              decorationThickness: 1.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    if (_isLoadingDetails)
                      const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Description: ${_product.description ?? ''}",
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
                          if (widget.isExpanded &&
                              _product.variants.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              "Variantes:",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ..._product.variants.map(
                              (v) => Text(
                                "• ${v.colorName} (${v.size}) : ${v.stockQuantity} en stock",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                          if (widget.isExpanded &&
                              _product.deliveryMessage != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              "Livraison: ${_product.deliveryPrice != null ? '${_product.deliveryPrice} FCFA' : 'Gratuite'}",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _product.deliveryMessage!,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          widget.isExpanded = !widget.isExpanded;
                        });
                      },
                      child: widget.isExpanded
                          ? Icon(
                              Icons.arrow_upward,

                              color: Colors.white,
                              size: 24,
                            )
                          : SvgPicture.asset(
                              "assets/icon/mdi_arrow-down-thin.svg",
                            ),
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
