// ignore_for_file: must_be_immutable

import 'package:binetatour/core/utils/media_url_resolver.dart';
import 'package:binetatour/core/utils/price_utils.dart';
import 'package:binetatour/core/widgets/smooth_reels_scroll_physics.dart';
import 'package:binetatour/data/models/product_model.dart';
import 'package:binetatour/presentation/shop/widget/product_details/product_details_action_sidebar.dart';
import 'package:binetatour/presentation/shop/widget/product_details/product_details_bottom_card.dart';
import 'package:binetatour/presentation/shop/widget/product_details/product_details_top_overlay.dart';
import 'package:binetatour/presentation/shop/widget/product_details/product_media_view.dart';
import 'package:binetatour/providers/product_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProductMediaGallery extends StatefulWidget {
  final ProductModel product;
  final int? itemIndex;
  final bool isMuted;
  final bool isActive;
  bool isExpanded;
  final VoidCallback onMuteToggle;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final List<String>? upcomingUrls;

  ProductMediaGallery({
    super.key,
    required this.product,
    this.itemIndex,
    this.isActive = true,
    required this.isExpanded,
    required this.isMuted,
    required this.onMuteToggle,
    this.onPause,
    this.onResume,
    this.upcomingUrls,
  });

  @override
  State<ProductMediaGallery> createState() => _ProductMediaGalleryState();
}

class _ProductMediaGalleryState extends State<ProductMediaGallery> {
  int _currentMediaIndex = 0;
  late PageController _horizontalController;
  late ProductModel _product;
  bool _isLoadingDetails = true;

  String _resolveUrl(String? url) => MediaUrlResolver.resolveUrl(url);

  bool _isVideoUrl(String url) => MediaUrlResolver.isVideoUrl(url);

  List<ProductContent>? _cachedMediaList;

  List<ProductContent> get _mediaContent {
    if (_cachedMediaList != null) return _cachedMediaList!;

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

        final rawThumb =
            (m.thumbnailUrl != null && m.thumbnailUrl!.trim().isNotEmpty)
            ? m.thumbnailUrl!
            : _product.effectiveThumbnailUrl;
        final resolvedThumb = _resolveUrl(rawThumb);

        return ProductContent(
          url: resolvedUrl,
          thumbnailUrl: resolvedThumb.isNotEmpty ? resolvedThumb : null,
          isVideo: isVid,
          isImage: isImg,
          isAudio: isAud,
          isNetwork: true,
        );
      }).toList();

      // If product has a primary video not present in media list, include it
      final primaryVid = _product.effectiveVideoUrl;
      if (primaryVid.isNotEmpty) {
        final resolvedPrimary = _resolveUrl(primaryVid);
        final alreadyInList = list.any((c) => c.url == resolvedPrimary);
        if (!alreadyInList) {
          list.insert(
            0,
            ProductContent(
              url: resolvedPrimary,
              thumbnailUrl: _product.effectiveThumbnailUrl.isNotEmpty
                  ? _resolveUrl(_product.effectiveThumbnailUrl)
                  : null,
              isVideo: true,
              isImage: false,
              isAudio: false,
              isNetwork: true,
            ),
          );
        }
      }

      list.sort((a, b) {
        if (a.isVideo && !b.isVideo) return -1;
        if (!a.isVideo && b.isVideo) return 1;
        return 0;
      });

      _cachedMediaList = list;
      return list;
    }

    final List<ProductContent> fallbackList = [];
    final vUrl = _product.effectiveVideoUrl;
    if (vUrl.isNotEmpty) {
      final resolvedVid = _resolveUrl(vUrl);
      final resolvedThumb = _resolveUrl(_product.effectiveThumbnailUrl);
      fallbackList.add(
        ProductContent(
          url: resolvedVid,
          thumbnailUrl: resolvedThumb.isNotEmpty ? resolvedThumb : null,
          isVideo: true,
          isImage: false,
          isAudio: false,
          isNetwork: true,
        ),
      );
    }
    final mImg = _product.mainImage;
    if (mImg != null && mImg.isNotEmpty) {
      final resolvedImg = _resolveUrl(mImg);
      final isVid = _isVideoUrl(resolvedImg);
      if (resolvedImg != _resolveUrl(vUrl)) {
        fallbackList.add(
          ProductContent(
            url: resolvedImg,
            isVideo: isVid,
            isImage: !isVid,
            isAudio: false,
            isNetwork: true,
          ),
        );
      }
    }

    _cachedMediaList = fallbackList;
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
    final hasFullDetails =
        _product.description != null && _product.description!.isNotEmpty;
    _isLoadingDetails = !hasFullDetails;

    if (!hasFullDetails) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchDetails();
        }
      });
    }
  }

  @override
  void didUpdateWidget(ProductMediaGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _cachedMediaList = null;
      _currentMediaIndex = 0;
      final cachedProduct = context.read<ProductProvider>().getCachedProduct(
        widget.product.id,
      );
      _product = cachedProduct ?? widget.product;
      final hasFullDetails =
          _product.description != null && _product.description!.isNotEmpty;
      _isLoadingDetails = !hasFullDetails;
      if (!hasFullDetails && mounted) {
        _fetchDetails();
      }
      // Reset horizontal page position
      if (_horizontalController.hasClients) {
        _horizontalController.jumpTo(0);
      }
    }
  }

  Future<void> _fetchDetails() async {
    final detailedProduct = await context
        .read<ProductProvider>()
        .fetchProductDetails(widget.product.id);
    if (mounted && detailedProduct != null) {
      final oldMediaList = _cachedMediaList;
      _product = detailedProduct;
      _cachedMediaList = null;
      final newMediaList = _mediaContent;
      // Preserve active playing first media so PageView NEVER recreates the video widget when details arrive
      if (oldMediaList != null &&
          oldMediaList.isNotEmpty &&
          newMediaList.isNotEmpty) {
        if (oldMediaList.first.isVideo) {
          _cachedMediaList = [
            oldMediaList.first,
            ...newMediaList.skip(newMediaList.first.isVideo ? 1 : 0),
          ];
        } else if (oldMediaList.first.url == newMediaList.first.url) {
          _cachedMediaList = [oldMediaList.first, ...newMediaList.skip(1)];
        }
      }
      // Precache secondary images in gallery for instant horizontal swipes
      for (final m in newMediaList) {
        if (m.isImage && m.url.startsWith('http')) {
          precacheImage(
            NetworkImage(m.url),
            context,
            onError: (_, _) {},
          ).catchError((_) {});
        }
      }
      setState(() {
        _isLoadingDetails = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoadingDetails = false;
      });
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaList = _mediaContent;
    final clampedIndex = _currentMediaIndex.clamp(0, mediaList.length - 1);
    final currentMedia = mediaList.isNotEmpty ? mediaList[clampedIndex] : null;
    final String currentUrl = currentMedia?.url ?? (_product.mainImage ?? '');
    final bool isVideoOrAudio =
        currentMedia != null && (currentMedia.isVideo || currentMedia.isAudio);

    return Stack(
      children: [
        // 1. Horizontal Media Gallery
        mediaList.isEmpty
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
                physics: const SmoothReelsScrollPhysics(),
                allowImplicitScrolling: true,
                itemCount: mediaList.length,
                onPageChanged: (i) => setState(() => _currentMediaIndex = i),
                itemBuilder: (context, index) {
                  final media = mediaList[index];
                  final isMediaActive =
                      widget.isActive && index == _currentMediaIndex;
                  final discPerc =
                      double.tryParse(_product.discountPercentage) ?? 0;

                  return ProductMediaView(
                    key: ValueKey('media_${_product.id}_${media.url}'),
                    media: media,
                    productId: _product.id,
                    itemIndex: widget.itemIndex,
                    mainImage: _product.mainImage,
                    isMuted: widget.isMuted,
                    isActive: isMediaActive,
                    upcomingUrls: widget.upcomingUrls,
                    title: _product.productName,
                    price: AppPriceUtils.formatPrice(
                      _product.priceAfterDiscount.isNotEmpty
                          ? _product.priceAfterDiscount
                          : _product.sellingPrice,
                    ),
                    oldPrice: discPerc > 0
                        ? AppPriceUtils.formatPrice(_product.sellingPrice)
                        : null,
                    discount: discPerc > 0 ? "-${discPerc.toInt()}%" : null,
                    thumbnailUrl:
                        media.thumbnailUrl ?? _product.effectiveThumbnailUrl,
                  );
                },
              ),

        // 2. Top Controls Overlay
        ProductDetailsTopOverlay(
          currentMediaIndex: _currentMediaIndex,
          mediaCount: mediaList.length,
          isVideoOrAudio: isVideoOrAudio,
          isMuted: widget.isMuted,
          onMuteToggle: widget.onMuteToggle,
          onClose: () => Navigator.pop(context),
        ),

        // 3. Right Floating Action Sidebar (Positioned at bottom-right)
        ProductDetailsActionSidebar(
          product: _product,
          currentMediaUrl: currentUrl,
          isExpanded: widget.isExpanded,
          onPause: widget.onPause,
          onResume: widget.onResume,
        ),

        // 4. Bottom Gradient Info & Purchase Card — isolated to prevent gradient repaints
        RepaintBoundary(
          child: ProductDetailsBottomCard(
            product: _product,
            isExpanded: widget.isExpanded,
            isLoadingDetails: _isLoadingDetails,
            onToggleExpand: () {
              setState(() {
                widget.isExpanded = !widget.isExpanded;
              });
            },
            onPause: widget.onPause,
            onResume: widget.onResume,
          ),
        ),
      ],
    );
  }
}
