import 'dart:ui';
import 'package:binetatour/core/utils/media_url_resolver.dart';
import 'package:binetatour/presentation/shop/widget/product_audio_item.dart';
import 'package:binetatour/presentation/shop/widget/product_video_item.dart';
import 'package:flutter/material.dart';

class ProductContent {
  final String url;
  final String? thumbnailUrl;
  final bool isVideo;
  final bool isImage;
  final bool isAudio;
  final bool isNetwork;

  ProductContent({
    required this.url,
    this.thumbnailUrl,
    required this.isVideo,
    required this.isImage,
    required this.isAudio,
    required this.isNetwork,
  });
}

class ProductMediaView extends StatelessWidget {
  final ProductContent media;
  final int productId;
  final int? itemIndex;
  final String? mainImage;
  final bool isMuted;
  final bool isActive;
  final List<String>? upcomingUrls;
  final String? heroTag;
  final String? title;
  final String? price;
  final String? oldPrice;
  final String? discount;
  final String? thumbnailUrl;

  const ProductMediaView({
    super.key,
    required this.media,
    required this.productId,
    this.itemIndex,
    this.mainImage,
    required this.isMuted,
    required this.isActive,
    this.upcomingUrls,
    this.heroTag,
    this.title,
    this.price,
    this.oldPrice,
    this.discount,
    this.thumbnailUrl,
  });

  String? _resolvePosterUrl() {
    final t = thumbnailUrl ?? media.thumbnailUrl;
    if (t != null && t.trim().isNotEmpty && !_isVideoUrl(t)) {
      return t.trim();
    }
    if (mainImage != null &&
        mainImage!.trim().isNotEmpty &&
        !_isVideoUrl(mainImage!)) {
      return mainImage!.trim();
    }
    return null;
  }

  static bool _isVideoUrl(String url) => MediaUrlResolver.isVideoUrl(url);

  @override
  Widget build(BuildContext context) {
    final Widget content;
    final posterUrl = _resolvePosterUrl();

    if (media.isVideo) {
      content = RepaintBoundary(
        child: ProductVideoItem(
          productId: productId,
          itemIndex: itemIndex,
          videoUrl: media.url,
          thumbnailUrl: posterUrl,
          isMuted: isMuted,
          isActive: isActive,
          upcomingUrls: upcomingUrls,
        ),
      );
    } else if (media.isAudio) {
      content = RepaintBoundary(
        child: ProductAudioItem(
          audioUrl: media.url,
          isMuted: isMuted,
          isActive: isActive,
        ),
      );
    } else {
      content = InteractiveViewer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred background image
            Positioned.fill(
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
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
                errorBuilder: (context, error, stackTrace) => const Center(
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

    return content;
  }
}
