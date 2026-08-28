// ignore_for_file: must_be_immutable

import 'dart:ui';
import 'package:binetatour/core/base_url/base_url.dart';
import 'package:binetatour/core/token_storage/token_storage.dart';
import 'package:binetatour/core/video/video_cache_manager.dart';
import 'package:binetatour/core/video/video_frame_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:binetatour/presentation/profile/widget/login_view.dart';
import 'package:binetatour/presentation/shop/vaildation_sceen.dart';
import 'package:binetatour/core/widgets/fireworks_overlay.dart';
import 'package:binetatour/presentation/shop/widget/cart_screen.dart';
import 'package:binetatour/presentation/shop/widget/product_video_item.dart';
import 'package:binetatour/presentation/shop/widget/product_audio_item.dart';
import 'package:binetatour/data/models/product_model.dart';
import 'package:binetatour/presentation/shop/shop_screen.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with WidgetsBindingObserver {
  late PageController _verticalController;
  bool _isMuted = false;
  int _currentPageIndex = 0;
  bool _isScreenPaused = false;

  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPageIndex = widget.initialProductIndex;
    _verticalController = PageController(
      initialPage: widget.initialProductIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheAround(_currentPageIndex);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (!_isScreenPaused && mounted) {
        setState(() => _isScreenPaused = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isScreenPaused && mounted) {
        setState(() => _isScreenPaused = false);
      }
    }
  }

  String _resolveUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    String clean = url.trim();
    if (!clean.startsWith('http') &&
        !clean.startsWith('file://') &&
        !clean.startsWith('/data')) {
      final base = BaseUrl.baseUrl;
      clean = clean.startsWith('/') ? '$base$clean' : '$base/$clean';
    }
    return clean;
  }

  void _precacheAround(int index) {
    if (!mounted) return;
    final nextIndex = index + 1;
    if (nextIndex < widget.allProducts.length) {
      final p = widget.allProducts[nextIndex];
      final vUrl = p.effectiveVideoUrl;
      if (vUrl.isNotEmpty) {
        final clean = _resolveUrl(vUrl);
        if (clean.isNotEmpty) {
          VideoCacheManager.instance.preCacheVideo(clean);
          VideoFrameManager.instance.extractFirstFrame(clean).ignore();
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          onPageChanged: (index) {
            setState(() {
              _currentPageIndex = index;
            });
            _precacheAround(index);
          },
          itemBuilder: (context, index) {
            final product = widget.allProducts[index];
            final isActive = index == _currentPageIndex && !_isScreenPaused;
            return ProductMediaGallery(
              product: product,
              isActive: isActive,
              isMuted: _isMuted,
              onMuteToggle: () => setState(() => _isMuted = !_isMuted),
              isExpanded: isExpanded,
              onPause: () {
                if (mounted) setState(() => _isScreenPaused = true);
              },
              onResume: () {
                if (mounted) setState(() => _isScreenPaused = false);
              },
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
  final bool isActive;
  bool isExpanded;
  final VoidCallback onMuteToggle;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  ProductMediaGallery({
    super.key,
    required this.product,
    this.isActive = true,
    required this.isExpanded,
    required this.isMuted,
    required this.onMuteToggle,
    this.onPause,
    this.onResume,
  });

  @override
  State<ProductMediaGallery> createState() => _ProductMediaGalleryState();
}

class _ProductMediaGalleryState extends State<ProductMediaGallery> {
  int _currentMediaIndex = 0;
  late PageController _horizontalController;
  late ProductModel _product;
  bool _isLoadingDetails = true;

  String _resolveUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    String clean = url.trim();
    if (!clean.startsWith('http') &&
        !clean.startsWith('file://') &&
        !clean.startsWith('/data')) {
      final base = BaseUrl.baseUrl;
      clean = clean.startsWith('/') ? '$base$clean' : '$base/$clean';
    }
    return clean;
  }

  bool _isVideoUrl(String url) {
    if (url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase().split('?').first.split('#').first;
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.m3u8') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.avi') ||
        clean.endsWith('.mkv') ||
        clean.endsWith('.flv') ||
        clean.endsWith('.3gp') ||
        clean.contains('.mp4') ||
        clean.contains('.m3u8');
  }

  List<ProductContent> get _mediaContent {
    if (_product.media.isNotEmpty) {
      final list = _product.media.map((m) {
        final rawUrl = m.effectiveMediaUrl.isNotEmpty
            ? m.effectiveMediaUrl
            : m.mediaUrl;
        final resolvedUrl = _resolveUrl(rawUrl);
        final isVid =
            m.mediaType.toLowerCase() == 'video' || _isVideoUrl(resolvedUrl);
        final isAud = m.mediaType.toLowerCase() == 'audio';
        final isImg = m.mediaType.toLowerCase() == 'image' && !isVid && !isAud;

        return ProductContent(
          url: resolvedUrl,
          isVideo: isVid,
          isImage: isImg,
          isAudio: isAud,
          isNetwork: true,
        );
      }).toList();

      // Video priority: Videos appear first before images
      list.sort((a, b) {
        if (a.isVideo && !b.isVideo) return -1;
        if (!a.isVideo && b.isVideo) return 1;
        return 0;
      });

      return list;
    }

    final List<ProductContent> fallbackList = [];
    final vUrl = _product.effectiveVideoUrl;
    if (vUrl.isNotEmpty) {
      final resolvedVid = _resolveUrl(vUrl);
      fallbackList.add(
        ProductContent(
          url: resolvedVid,
          isVideo: true,
          isImage: false,
          isAudio: false,
          isNetwork: true,
        ),
      );
    }

    if (_product.mainImage != null && _product.mainImage!.isNotEmpty) {
      final resolvedMain = _resolveUrl(_product.mainImage!);
      final isVid = _isVideoUrl(resolvedMain);
      if (!fallbackList.any((e) => e.url == resolvedMain)) {
        fallbackList.add(
          ProductContent(
            url: resolvedMain,
            isVideo: isVid,
            isImage: !isVid,
            isAudio: false,
            isNetwork: true,
          ),
        );
      }
    }

    return fallbackList;
  }

  @override
  void initState() {
    super.initState();
    _horizontalController = PageController();
    final cachedProduct = context.read<ProductProvider>().getCachedProduct(
      widget.product.id,
    );
    _product = cachedProduct ?? widget.product;
    if (_product.media.isNotEmpty ||
        (_product.mainImage != null && _product.mainImage!.isNotEmpty) ||
        _product.effectiveVideoUrl.isNotEmpty) {
      _isLoadingDetails = false;
    }
    _fetchDetails();
  }

  @override
  void didUpdateWidget(ProductMediaGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product != widget.product) {
      final cachedProduct = context.read<ProductProvider>().getCachedProduct(
        widget.product.id,
      );
      _product = cachedProduct ?? widget.product;
    }
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
                  final isMediaActive =
                      widget.isActive && index == _currentMediaIndex;
                  if (media.isVideo) {
                    return ProductVideoItem(
                      productId: _product.id,
                      videoUrl: media.url,
                      thumbnailUrl: _product.mainImage,
                      isMuted: widget.isMuted,
                      isActive: isMediaActive,
                    );
                  } else if (media.isAudio) {
                    return ProductAudioItem(
                      audioUrl: media.url,
                      isMuted: widget.isMuted,
                      isActive: isMediaActive,
                    );
                  } else {
                    return InteractiveViewer(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Blurred background image
                          Positioned.fill(
                            child: ClipRect(
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 15.0,
                                  sigmaY: 15.0,
                                ),
                                child: Image.network(
                                  media.url,
                                  fit: BoxFit.cover,
                                  color: Colors.black.withValues(alpha: 0.35),
                                  colorBlendMode: BlendMode.darken,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox(),
                                ),
                              ),
                            ),
                          ),
                          // Clear foreground image
                          Center(
                            child: Image.network(
                              media.url,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 100,
                                      color: Colors.white54,
                                    ),
                                  ),
                            ),
                          ),
                        ],
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
                  widget.onPause?.call();
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
                      widget.onResume?.call();
                      return; // Still not logged in
                    }
                  }

                  if (!mounted) {
                    widget.onResume?.call();
                    return;
                  }

                  if (_product.isOutOfStock) {
                    widget.onResume?.call();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          "Ce produit est en rupture de stock !",
                          textAlign: TextAlign.center,
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.all(20),
                      ),
                    );
                    return;
                  }

                  try {
                    await context.read<CartProvider>().addToCart(_product);
                    if (!mounted) {
                      widget.onResume?.call();
                      return;
                    }
                    FireworksOverlay.show(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          "Produit ajouté au panier avec succès !",
                          textAlign: TextAlign.center,
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
                    await Future.delayed(const Duration(seconds: 1));
                    if (!mounted) {
                      widget.onResume?.call();
                      return;
                    }
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true, // Allows it to take more height
                      backgroundColor: Colors.transparent,
                      builder: (context) => const CartBottomSheet(),
                    );
                    widget.onResume?.call();
                  } catch (e) {
                    widget.onResume?.call();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Impossible d'ajouter au panier : $e",
                          textAlign: TextAlign.center,
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.all(20),
                      ),
                    );
                  }
                },
                child: _buildActionIcon(Icons.add, "Panier"),
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () async {
                  String productUrl = '';

                  if (_mediaContent.isNotEmpty) {
                    productUrl = _mediaContent[_currentMediaIndex].url;
                  } else if (_product.mainImage != null) {
                    productUrl = _product.mainImage!;
                  }

                  final String shareText = productUrl.isNotEmpty
                      ? "Bonjour, je souhaite commander ce produit : $productUrl.\nVoici mes informations de livraison :\n\n* Adresse ?\n* Heure souhaitée ?\n* Numéro téléphone ?"
                      : "Bonjour, je souhaite commander ce produit.\nVoici mes informations de livraison :\n\n* Adresse ?\n* Heure souhaitée ?\n* Numéro téléphone ?";

                  final String phoneNumber =
                      dotenv.env["WHATSAPP_PHONE"] ?? "+221771635015";

                  final whatsappAppUrl = Uri.parse(
                    "whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(shareText)}",
                  );
                  final whatsappWebUrl = Uri.parse(
                    "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(shareText)}",
                  );

                  bool launched = false;

                  try {
                    launched = await launchUrl(
                      whatsappAppUrl,
                      mode: LaunchMode.externalNonBrowserApplication,
                    );
                  } catch (e) {
                    launched = false;
                  }

                  if (!launched) {
                    try {
                      launched = await launchUrl(
                        whatsappAppUrl,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      launched = false;
                    }
                  }

                  if (!launched) {
                    try {
                      launched = await launchUrl(
                        whatsappWebUrl,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      launched = false;
                    }
                  }

                  if (!launched) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "WhatsApp n'est pas installé sur cet appareil et impossible d'ouvrir le navigateur.",
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
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
                        widget.onPause?.call();
                        final token = await TokenStorage.getAccessToken();
                        if (token == null || token.isEmpty) {
                          if (!context.mounted) {
                            widget.onResume?.call();
                            return;
                          }
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
                            widget.onResume?.call();
                            return; // Still not logged in
                          }
                        }

                        if (!context.mounted) {
                          widget.onResume?.call();
                          return;
                        }

                        if (_product.isOutOfStock) {
                          widget.onResume?.call();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                "Ce produit est en rupture de stock !",
                                textAlign: TextAlign.center,
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: const EdgeInsets.all(20),
                            ),
                          );
                          return;
                        }

                        // Show a loading dialog while the product is added to the cart
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF6900),
                            ),
                          ),
                        );

                        bool success = false;
                        try {
                          await context.read<CartProvider>().addToCart(
                            _product,
                          );
                          success = true;
                        } catch (e) {
                          debugPrint("Error adding product to cart: $e");
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Impossible de passer la commande : $e",
                                  textAlign: TextAlign.center,
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                margin: const EdgeInsets.all(20),
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted) {
                            Navigator.pop(context); // Dismiss loading dialog
                          }
                        }

                        if (!context.mounted || !success) {
                          widget.onResume?.call();
                          return;
                        }

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ValidationScreen(),
                          ),
                        );

                        widget.onResume?.call();
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
                          if (widget.isExpanded) ...[
                            const SizedBox(height: 10),
                            if (_product.isProductMode) ...[
                              Text(
                                "Stock: ${_product.totalStock} en stock",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ] else ...[
                              const Text(
                                "Variantes & Stock:",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_product.isMixedMode &&
                                  _product.unassignedStock > 0)
                                Text(
                                  "• Sans préférence : ${_product.unassignedStock} en stock",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ..._product.variants.map(
                                (v) => Text(
                                  "• ${v.colorName} (${v.size}) : ${v.stockQuantity} en stock",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
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
        Text(
          String.fromCharCode(icon.codePoint),
          style: TextStyle(
            inherit: false,
            fontSize: 28,
            fontFamily: icon.fontFamily,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
