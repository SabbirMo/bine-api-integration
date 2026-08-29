import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/core/base_url/base_url.dart';
import 'package:binetatour/data/models/product_model.dart';
import 'package:binetatour/providers/cart_provider.dart';
import 'package:binetatour/providers/product_provider.dart';

/// Renders either:
/// 1. A valid image thumbnail (if available and not a video file)
/// 2. Product thumbnail if available
/// 3. Automatically resolves product details using [productId] if the cart/order item has no explicit image
class ProductThumbnailOrVideoFrame extends StatefulWidget {
  final String? imageUrl;
  final String? videoUrl;
  final int? productId;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const ProductThumbnailOrVideoFrame({
    super.key,
    this.imageUrl,
    this.videoUrl,
    this.productId,
    this.width = 80,
    this.height = 80,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  State<ProductThumbnailOrVideoFrame> createState() =>
      _ProductThumbnailOrVideoFrameState();
}

class _ProductThumbnailOrVideoFrameState
    extends State<ProductThumbnailOrVideoFrame> {
  bool _imageLoadFailed = false;
  ProductModel? _fetchedProduct;

  @override
  void initState() {
    super.initState();
    _checkAndFetchMissingDetails();
  }

  @override
  void didUpdateWidget(covariant ProductThumbnailOrVideoFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.productId != widget.productId) {
      _imageLoadFailed = false;
      _checkAndFetchMissingDetails();
    }
  }

  static bool isVideoUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
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

  static String resolveUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    String clean = url.trim();
    if (!clean.startsWith('http')) {
      final base = BaseUrl.baseUrl;
      clean = clean.startsWith('/') ? '$base$clean' : '$base/$clean';
    }
    return clean;
  }

  void _checkAndFetchMissingDetails() {
    final hasValidImage =
        widget.imageUrl != null &&
        widget.imageUrl!.trim().isNotEmpty &&
        !isVideoUrl(widget.imageUrl);

    final rawVideo =
        (widget.videoUrl != null && widget.videoUrl!.trim().isNotEmpty)
        ? widget.videoUrl!
        : (isVideoUrl(widget.imageUrl) ? widget.imageUrl! : '');

    if (!hasValidImage &&
        rawVideo.isEmpty &&
        widget.productId != null &&
        widget.productId! > 0) {
      final productId = widget.productId!;
      final cartProv = context.read<CartProvider>();
      final prodProv = context.read<ProductProvider>();

      if (cartProv.getProductFromCache(productId) != null) {
        _fetchedProduct = cartProv.getProductFromCache(productId);
      } else if (prodProv.getCachedProduct(productId) != null) {
        _fetchedProduct = prodProv.getCachedProduct(productId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius =
        widget.borderRadius ?? BorderRadius.circular(10);

    // 1. Determine active Image URL
    String activeImageUrl = '';
    if (widget.imageUrl != null &&
        widget.imageUrl!.trim().isNotEmpty &&
        !isVideoUrl(widget.imageUrl)) {
      activeImageUrl = resolveUrl(widget.imageUrl);
    } else if (_fetchedProduct != null &&
        _fetchedProduct!.effectiveThumbnailUrl.isNotEmpty &&
        !isVideoUrl(_fetchedProduct!.effectiveThumbnailUrl)) {
      activeImageUrl = resolveUrl(_fetchedProduct!.effectiveThumbnailUrl);
    }

    // 2. Determine active Video URL
    String activeVideoUrl = '';
    if (widget.videoUrl != null && widget.videoUrl!.trim().isNotEmpty) {
      activeVideoUrl = resolveUrl(widget.videoUrl);
    } else if (widget.imageUrl != null && isVideoUrl(widget.imageUrl)) {
      activeVideoUrl = resolveUrl(widget.imageUrl);
    } else if (_fetchedProduct != null &&
        _fetchedProduct!.effectiveVideoUrl.isNotEmpty) {
      activeVideoUrl = resolveUrl(_fetchedProduct!.effectiveVideoUrl);
    }

    Widget content;

    if (activeImageUrl.isNotEmpty && !_imageLoadFailed) {
      content = Image.network(
        activeImageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          if (activeVideoUrl.isNotEmpty) {
            return _buildVideoFrame(activeVideoUrl);
          }
          return _buildFallbackShimmer();
        },
      );
    } else if (activeVideoUrl.isNotEmpty) {
      content = _buildVideoFrame(activeVideoUrl);
    } else {
      content = _buildFallbackShimmer();
    }

    return ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFF1E1E1E),
        child: content,
      ),
    );
  }

  Widget _buildVideoFrame(String vUrl) {
    return _buildFallbackShimmer();
  }

  Widget _buildFallbackShimmer() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFF222224),
      child: const Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          color: Color(0xFF666666),
          size: 22,
        ),
      ),
    );
  }
}
