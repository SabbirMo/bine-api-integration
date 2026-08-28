// ignore_for_file: must_be_immutable

import 'package:binetatour/core/base_url/base_url.dart';
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

        final rawThumb = (m.thumbnailUrl != null && m.thumbnailUrl!.trim().isNotEmpty)
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchDetails();
      }
    });
  }

  @override
  void didUpdateWidget(ProductMediaGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product != widget.product) {
      final cachedProduct = context.read<ProductProvider>().getCachedProduct(
        widget.product.id,
      );
      _product = cachedProduct ?? widget.product;
      final hasFullDetails =
          _product.description != null && _product.description!.isNotEmpty;
      _isLoadingDetails = !hasFullDetails;
      if (mounted) {
        _fetchDetails();
      }
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
    final mediaList = _mediaContent;
    final String currentUrl = mediaList.isNotEmpty
        ? mediaList[_currentMediaIndex.clamp(0, mediaList.length - 1)].url
        : (_product.mainImage ?? '');

    final bool isVideoOrAudio =
        mediaList.isNotEmpty &&
        (mediaList[_currentMediaIndex.clamp(0, mediaList.length - 1)].isVideo ||
            mediaList[_currentMediaIndex.clamp(0, mediaList.length - 1)]
                .isAudio);

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
                itemCount: mediaList.length,
                onPageChanged: (i) => setState(() => _currentMediaIndex = i),
                itemBuilder: (context, index) {
                  final media = mediaList[index];
                  final isMediaActive =
                      widget.isActive && index == _currentMediaIndex;
                  return ProductMediaView(
                    media: media,
                    productId: _product.id,
                    mainImage: _product.mainImage,
                    isMuted: widget.isMuted,
                    isActive: isMediaActive,
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

        // 3. Right Floating Action Sidebar
        ProductDetailsActionSidebar(
          product: _product,
          currentMediaUrl: currentUrl,
          isExpanded: widget.isExpanded,
          onPause: widget.onPause,
          onResume: widget.onResume,
        ),

        // 4. Bottom Gradient Info & Purchase Card
        ProductDetailsBottomCard(
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
      ],
    );
  }
}
